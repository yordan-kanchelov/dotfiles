# 0011. Native Windows and WSL setup

Status: Accepted, 2026-11-20

## Context

`bootstrap.ps1` sets up native Windows: WinGet packages, the PowerShell profile, fonts and a Terminal fragment. It then installs Ubuntu on WSL 2 and runs the same playbook there. It must work under Windows PowerShell 5.1 as well as PowerShell 7, and it must not damage an existing profile.

## Decision

### PowerShell 5.1 compatibility

- Native stderr is treated as data. Windows PowerShell 5 can turn native stderr into a terminating error.
- The progress bar is turned off for downloads, because it makes Windows PowerShell 5 downloads many times slower.
- Native output is decoded with the console code page, and Herdr writes UTF-8. The Herdr installer switches the console encoding and restores the caller's setting afterwards. Without a console the setter throws, and nothing changes.
- Directory moves in Windows PowerShell 5.1 must stay on one drive. Herdr migration therefore stages inside the profile directory itself, because a redirected profile may sit on another drive.
- Native and Ansible progress share the success pipeline with `setup-wsl.ps1`'s final status. `bootstrap.ps1` picks out the object carrying `ResumeStatus` and passes everything else through. `windows.yml` parses only the final compact JSON, because ShouldProcess writes readable preview lines before it.

### Paths and environment

- PATH changes keep both the paths injected into the session and the paths installers just added.
- Codex injects its private `rg.exe` into its own process, and regular terminals cannot use it. A tool found under `.codex\packages` therefore does not count as installed.
- The profile adds Git for Windows' `file.exe` to Yazi's environment, because Yazi needs it for MIME detection.
- Herdr autostart resolves `herdr` from the login PATH, so it does not pin a versioned install directory.
- `verify-agents.ps1` deliberately discards the inherited process PATH and checks the persistent user and machine PATH, which is what a fresh Windows login receives.
- The Herdr installer honours the same redirect variables as `scripts/install-herdr.sh`. Herdr and the agents read them too.

### Never destroy user data

- Existing links are moved; the scripts never recursively delete or follow them. `Directory.Delete` on a link removes the link itself without walking its target.
- Herdr's `config.toml` is a single file, not a directory, so it cannot be a junction. It is written as a managed file, like the PowerShell profile block. Older dotfiles linked the whole Claude skills directory into the checkout, and the Herdr installer migrates that link to a local copy.
- Font registration never uses `New-Item -Force` on the fonts registry key, because that empties an existing key, unrelated fonts included. Faces that are already installed are kept, and only missing ones are fetched. The archive comes from a URL or local path, so fonts are not stored in the repository. Only the wanted faces are extracted, which leaves no staging directory to clean up. Archive paths are resolved explicitly, because `ZipFile` resolves relative paths against the process directory, not the PowerShell location.
- `Restart-Computer` runs without `-Force`, so applications with unsaved work are not closed forcibly. Resuming never grants reboot permission that the initial run did not save.
- PSReadLine history suggestions stay local. No account or history sync is configured.

### WSL

- `enable-wsl-platform.ps1` is the only elevated step, and only for the Windows feature. Linux and user provisioning stay unelevated.
- `wsl.exe` in System32 dispatches both MSIX/Store and MSI installations of WSL. The scripts do not pin the old Program Files layout, because current Microsoft.WSL packages use MSIX.
- Installing the WSL MSI alone does not enable the WSL 2 Windows feature. CIM can inspect the feature without admin rights, so reruns on a working machine do not ask for UAC.
- With no distributions installed, `wsl.exe` exits non-zero. The scripts rely on its error code, which is not localised, rather than its text.
- Ubuntu's first start is deliberately visible, because it asks the user for a username and password. The script does not wait for that shell to exit once OOBE has created the account.
- `bootstrap-wsl.sh` is written with LF even from a CRLF Windows checkout, and arguments pass through without `bash -c` interpolation.
- Inside Ubuntu, `bootstrap-wsl.sh` runs as the normal user, and Ansible does all tool and config provisioning. Tag clones detach HEAD, so a rerun happens only at the fetched commit and never moves it. Ansible logs persist across console closes and restarts, and no passwords are stored.
- `tasks/wsl.yml` edits `/etc/wsl.conf` in place (systemd and the default user) and keeps the automount, network and interop settings rather than replacing the file.
- `windows.yml` runs from Ubuntu/WSL and targets the native Windows user through WSL interop. It needs no WinRM listener, no Windows SSH server and no Linux coding-agent install.
- Tailscale is installed only. Joining a tailnet needs the user's own sign-in.
- `wsl-resume-state.ps1` holds the resume state logic shared by the launcher and its isolated registry and file regression test.

## Consequences

Every Windows script has to parse and run under Windows PowerShell 5.1. `test-windows.yml` runs them on `windows-latest`.
