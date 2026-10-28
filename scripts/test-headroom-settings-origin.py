"""Check the Headroom settings fix against an optional installed source file."""

import argparse
import ast
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, help="Path to Headroom settings_store.py")
options, test_args = parser.parse_known_args()
SOURCE = options.source
if SOURCE is not None and not SOURCE.is_file():
    parser.error(f"Headroom source does not exist: {SOURCE}")
if SOURCE is None:
    package = importlib.util.find_spec("headroom")
    if package and package.submodule_search_locations:
        SOURCE = Path(next(iter(package.submodule_search_locations))) / "settings_store.py"


@unittest.skipUnless(SOURCE and SOURCE.is_file(), "optional Headroom source is not installed")
class SettingsOriginTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        directory = Path(scratch.name)
        self.directory = directory
        paths = types.ModuleType("headroom.paths")
        paths.settings_path = lambda: directory / "settings.json"
        paths.ensure_workspace_dir = lambda: directory.mkdir(exist_ok=True)
        package = types.ModuleType("headroom")
        package.paths = paths
        self.env = patch.dict(os.environ, {}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        spec = importlib.util.spec_from_file_location("_headroom_settings_test", SOURCE)
        self.store = importlib.util.module_from_spec(spec)
        modules = patch.dict(sys.modules, {
            "headroom": package,
            "headroom.paths": paths,
            spec.name: self.store,
        })
        modules.start()
        self.addCleanup(modules.stop)
        spec.loader.exec_module(self.store)
        package.settings_store = self.store

    def field(self, key="log_messages", **kwargs):
        return next(f for f in self.store.to_schema(**kwargs)["fields"] if f["key"] == key)

    def runtime_functions(self, **globals):
        source = SOURCE.parent / "install/runtime.py"
        if not source.is_file():
            self.skipTest("native runtime source is not beside settings_store.py")
        tree = ast.parse(source.read_text())
        functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)
                     and node.name in {"_runtime_env", "_deployment_env", "start_detached_agent"}]
        namespace = {"os": os, "settings_store": self.store, **globals}
        future = ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0)
        module = ast.fix_missing_locations(ast.Module(body=[future, *functions], type_ignores=[]))
        exec(compile(module, str(source), "exec"), namespace)
        return namespace

    def test_saved_setting_stays_editable_after_startup_and_reapply(self):
        self.store.save({"log_messages": True})
        for _ in range(2):
            self.store.apply_to_environ(self.store.load())
        field = self.field(runtime_values={"log_messages": True})
        self.assertTrue(field["value"])
        self.assertTrue(field["stored"])
        self.assertFalse(field["env_override"])

    def test_saved_false_stays_editable(self):
        self.store.save({"log_messages": False})
        self.store.apply_to_environ(self.store.load())
        self.assertFalse(self.field()["value"])
        self.assertFalse(self.field()["env_override"])

    def test_preexisting_export_stays_locked_even_when_equal_to_file(self):
        for value in ("1", "true"):
            with self.subTest(value=value):
                os.environ["HEADROOM_LOG_MESSAGES"] = value
                self.store.save({"log_messages": True})
                self.store.apply_to_environ(self.store.load())
                self.assertTrue(self.field()["value"])
                self.assertTrue(self.field()["env_override"])

    def test_changed_environment_stays_locked_after_reapply(self):
        self.store.save({"log_messages": True})
        self.store.apply_to_environ(self.store.load())
        os.environ["HEADROOM_LOG_MESSAGES"] = "0"
        self.store.apply_to_environ(self.store.load())
        self.assertFalse(self.field()["value"])
        self.assertTrue(self.field()["env_override"])

    def test_profile_exclusions_still_apply(self):
        os.environ["HEADROOM_MODE"] = "cache"
        field = self.field("mode", env_override_exclusions={"HEADROOM_MODE"})
        self.assertEqual(field["value"], "cache")
        self.assertFalse(field["env_override"])

    def test_child_environment_drops_only_unchanged_file_values(self):
        os.environ["PATH"] = "/synthetic/bin"
        os.environ["HEADROOM_LOG_FILE"] = "/synthetic/requests.jsonl"
        self.store.apply_to_environ({"log_messages": True, "log_file": "/synthetic/requests.jsonl"})
        child = self.store.child_environ()
        self.assertNotIn("HEADROOM_LOG_MESSAGES", child)
        self.assertEqual(child["HEADROOM_LOG_FILE"], "/synthetic/requests.jsonl")
        self.assertEqual(child["PATH"], "/synthetic/bin")
        self.assertEqual(os.environ["HEADROOM_LOG_MESSAGES"], "1")
        os.environ["HEADROOM_LOG_MESSAGES"] = "0"
        self.assertEqual(self.store.child_environ()["HEADROOM_LOG_MESSAGES"], "0")

    def test_native_runtime_reloads_settings_without_losing_explicit_overrides(self):
        namespace = self.runtime_functions()
        self.store.save({"log_messages": True})
        self.store.apply_to_environ(self.store.load())
        manifest = types.SimpleNamespace(base_env={"HEADROOM_LOG_FILE": "/synthetic/log"},
                                         profile="evaluation", preset="persistent-service",
                                         runtime_kind="python", supervisor_kind="service", scope="provider")
        child = namespace["_runtime_env"](manifest)
        self.assertNotIn("HEADROOM_LOG_MESSAGES", child)
        self.assertEqual(child["HEADROOM_DEPLOYMENT_PROFILE"], "evaluation")
        manifest.base_env["HEADROOM_LOG_MESSAGES"] = "0"
        child = namespace["_runtime_env"](manifest)
        self.assertEqual(child["HEADROOM_LOG_MESSAGES"], "0")

    def test_detached_agent_drops_file_values_and_preserves_real_exports(self):
        calls = []
        namespace = self.runtime_functions(
            subprocess=types.SimpleNamespace(Popen=lambda command, **kwargs: calls.append(kwargs)),
            resolve_headroom_command=lambda: ["headroom"],
            log_path=lambda profile: self.directory / "runner.log",
            _is_windows=lambda: False,
        )
        self.store.apply_to_environ({"log_messages": True})
        namespace["start_detached_agent"]("evaluation")
        self.assertNotIn("HEADROOM_LOG_MESSAGES", calls[-1]["env"])
        os.environ["HEADROOM_LOG_MESSAGES"] = "0"
        namespace["start_detached_agent"]("evaluation")
        self.assertEqual(calls[-1]["env"]["HEADROOM_LOG_MESSAGES"], "0")

    def test_macos_malloc_reexec_preserves_origin_and_tuning(self):
        source = SOURCE.parent / "cli/proxy.py"
        if not source.is_file():
            self.skipTest("proxy CLI source is not beside settings_store.py")
        tree = ast.parse(source.read_text())
        functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)
                     and node.name in {"_reexec_with_malloc_tuning", "_get_env_bool"}]
        tuning = next(node.value for node in tree.body if isinstance(node, ast.Assign)
                      and any(isinstance(target, ast.Name) and target.id == "_MALLOC_TUNING"
                              for target in node.targets))
        calls = []
        namespace = {
            "os": types.SimpleNamespace(environ=os.environ,
                                        execv=lambda *args: calls.append(("execv", args)),
                                        execve=lambda *args: calls.append(("execve", args))),
            "sys": types.SimpleNamespace(platform="darwin", executable="/synthetic/python",
                                         argv=["headroom", "proxy"]),
            "_MALLOC_TUNING": ast.literal_eval(tuning),
            "_process_is_headroom_cli_entrypoint": lambda: True,
        }
        exec(compile(ast.Module(body=functions, type_ignores=[]), str(source), "exec"), namespace)
        os.environ["HEADROOM_LOG_FILE"] = "/synthetic/log"
        self.store.apply_to_environ({"log_messages": True, "log_file": "/synthetic/log"})
        for explicit in (None, "0"):
            with self.subTest(explicit=explicit):
                os.environ.pop("_HEADROOM_MALLOC_TUNED", None)
                for key in namespace["_MALLOC_TUNING"]:
                    os.environ.pop(key, None)
                if explicit is not None:
                    os.environ["HEADROOM_LOG_MESSAGES"] = explicit
                namespace["_reexec_with_malloc_tuning"]()
                method, args = calls[-1]
                self.assertEqual(method, "execve")
                child = args[2]
                if explicit is None:
                    self.assertNotIn("HEADROOM_LOG_MESSAGES", child)
                else:
                    self.assertEqual(child["HEADROOM_LOG_MESSAGES"], explicit)
                self.assertEqual(child["HEADROOM_LOG_FILE"], "/synthetic/log")
                self.assertEqual(child["_HEADROOM_MALLOC_TUNED"], "1")
                for key, value in namespace["_MALLOC_TUNING"].items():
                    self.assertEqual(child[key], value)
                count = len(calls)
                namespace["_reexec_with_malloc_tuning"]()
                self.assertEqual(len(calls), count)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *test_args])
