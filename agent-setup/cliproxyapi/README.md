# CLIProxyAPI gateway

[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) turns OAuth logins from Claude and ChatGPT into local Claude, OpenAI Responses and Chat APIs. [cliproxyapi-dashboard](https://github.com/itsmylife44/cliproxyapi-dashboard) adds a web UI for logins, keys, quotas and logs.

Plain `claude`, `codex`, `pi` and `hermes` go straight to their providers. Only the `codexx` alias uses the gateway. If Docker is stopped, the plain commands keep working.

## Install

The stack needs Docker Desktop running and lives outside this repo.

```sh
git clone https://github.com/itsmylife44/cliproxyapi-dashboard ~/.local/share/cliproxyapi-dashboard
cd ~/.local/share/cliproxyapi-dashboard
git checkout bf6c629   # reviewed dashboard revision
./setup-local.sh       # answer n to the Perplexity sidecar
```

The compose file defaults to CLIProxyAPI v8.0.29. The `CLIPROXYAPI_IMAGE_TAG` line in `.env` overrides it, and the dashboard's updater writes that line. This machine runs v8.0.47.

The script writes `.env` and `config.local.yaml` (both mode 600) with random secrets, then starts four containers. Every port binds to `127.0.0.1`. The dashboard is at <http://localhost:3000> and the API at <http://127.0.0.1:8317>. The hostnames below replace both with port-free URLs.

Before the first run, read `docker-compose.local.yml`. Two details matter:

- The `docker-socket-proxy` image is unpinned (`:latest`) and lets the dashboard create and stop containers.
- `config.local.yaml` enables remote management on the container's port. The host mapping keeps it on localhost.

## Log in

1. Start the hostname proxy from [Local hostnames](#local-hostnames), then open <http://dashboard.local-cliproxyapi.localhost> and create the admin account.
2. Add the Claude provider and the Codex (OpenAI) provider. Both use a browser OAuth login.
3. Check the models. The list should include `gpt-6.1-sol`.

```sh
key=$(sed -n '/^api-keys:/{n;s/^ *- *"\(.*\)"$/\1/p;}' ~/.local/share/cliproxyapi-dashboard/config.local.yaml)
curl -s -H @- http://local-cliproxyapi.localhost/v1/models <<<"Authorization: Bearer $key"
```

The header goes through stdin, so the key never shows in the process list.

OAuth tokens live in the `cliproxyapi_auths` Docker volume. The client key in `config.local.yaml` is the only secret the alias reads.

## Local hostnames

Two names share port 80, so no URL needs a port.

| Name | Goes to |
| --- | --- |
| `http://local-cliproxyapi.localhost` | The API (`cliproxyapi:8317`) |
| `http://dashboard.local-cliproxyapi.localhost` | The dashboard (`dashboard:3000`) |

`.localhost` names resolve to loopback on their own, so there is no hosts entry and no `sudo`. A public suffix such as `.com` would be unsafe. `codexx` sends your key and prompts over plain HTTP, and anyone who registered the name could receive them.

A Caddy container does the routing by hostname. It publishes `127.0.0.1:80` only, uses an image pinned by digest, and restarts with Docker. The routes live in [Caddyfile](Caddyfile). Bring it up from the dotfiles root once the stack is running:

```sh
docker compose -p cliproxyapi-edge -f agent-setup/cliproxyapi/docker-compose.port80.yml up -d
curl -s -o /dev/null -w '%{http_code}\n' http://local-cliproxyapi.localhost/
```

Docker cannot remove the shared network while the proxy is attached. Take it down before `./setup-local.sh --down` or `--reset`:

```sh
docker compose -p cliproxyapi-edge -f agent-setup/cliproxyapi/docker-compose.port80.yml down
```

### Why the dashboard is on port 3000

The dashboard container listens on 3000, the Next.js default, and its compose file publishes that port on `127.0.0.1:3000`. Browsers assume port 80 for plain HTTP, but only one process can hold it. The proxy holds it and picks the target from the hostname. Port 3000 stays as a direct fallback if the proxy is down. The API's own port, 8317, works the same way.

### Custom name through the hosts file

To use a name of your own, map it to loopback in `/etc/hosts`. This needs `sudo`. Run it in a normal terminal, because a password prompt may not work from inside an agent session.

```sh
grep -q 'local-cliproxyapi.test' /etc/hosts || echo '127.0.0.1 local-cliproxyapi.test' | sudo tee -a /etc/hosts
curl -s -o /dev/null -w '%{http_code}\\n' http://local-cliproxyapi.test/
```

Add the same name to the two host lines in the [Caddyfile](Caddyfile) and recreate the proxy, or it answers 404. Use a reserved suffix such as `.test` or `.localhost`. A public suffix like `.com` can leak your key and prompts if the entry is ever missing. Then set `CPA_URL=http://local-cliproxyapi.test` in your shell and use the same host in Pi's `baseUrl`. To undo it, delete that line from `/etc/hosts`.

Without the proxy, set `CPA_URL=http://local-cliproxyapi.localhost:8317`, and use the same host and port in Pi's `baseUrl`.

## Alias

[zsh/.zshrc.core](../../zsh/.zshrc.core) defines one function, `codexx`. It starts Claude Code on `gpt-6.1-sol` through the gateway (`/v1/messages`). It reads the client key from the stack's config, so no key sits in this repo.

The base URL is `http://local-cliproxyapi.localhost`. Set `CPA_URL` to change it. `codexx` passes its environment through `--settings`, which overrides the `env` map in `~/.claude/settings.json`. It also sets the subagent model, effort controls, a tool concurrency of 3, and turns tool search off. Extra arguments pass through, so `codexx --continue` works. Claude Code warns that it does not recognise `gpt-6.1-sol` and assumes a 200k window. The warning is harmless.

Plain `claude`, `codex`, `pi` and `hermes` have no gateway route and use their native providers. Pi's `models.json` and Hermes's `model.base_url` hold no gateway settings.

## Operate

```sh
cd ~/.local/share/cliproxyapi-dashboard
docker compose -f docker-compose.local.yml ps
./setup-local.sh --down    # stop
./setup-local.sh           # start again; keeps the existing .env
```

`./setup-local.sh --reset` deletes the volumes, which removes the OAuth logins.

Containers use `restart: unless-stopped`, so they return when Docker Desktop starts. Enable "Start Docker Desktop when you sign in" if you want that after a reboot.

## Limits

- The dashboard's one-click CLIProxyAPI update recreates the container with a `wget` health check that the image lacks. The API keeps working, but Docker marks it unhealthy. Recreate it from compose, which keeps the tag from `.env`:

  ```sh
  cd ~/.local/share/cliproxyapi-dashboard
  docker compose -f docker-compose.local.yml up -d --no-deps cliproxyapi
  ```

- Claude Code features tuned for Claude models, such as tool search and effort, behave differently on GPT models.
- The gateway uses your subscription logins. Check the provider's terms before relying on it for heavy automation.
- The gateway has no compression. Headroom was removed because this setup needs routing, not token compression. RTK still filters command output; see [context-tools](../context-tools/README.md).

## Retire Headroom

Headroom listened on `127.0.0.1:8787`. A session started before the config change keeps using that port until you restart it. Stopping the service is safe only after every open Claude, Codex, Pi and Hermes session has restarted.

Live configs were backed up to `~/.dotfiles_backup/<timestamp>-headroom-removal/`. To undo a change, copy the file back from that folder.

```sh
launchctl bootout "gui/$(id -u)/com.headroom.evaluation"
launchctl bootout "gui/$(id -u)/com.dotfiles.headroom-logrotate"
rm ~/Library/LaunchAgents/com.headroom.evaluation.plist ~/Library/LaunchAgents/com.dotfiles.headroom-logrotate.plist
uv tool uninstall headroom-ai
```

`~/.headroom` holds about 160 MB of savings history and the CCR store. Delete it only when you no longer want that data.
