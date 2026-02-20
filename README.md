[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/atj4me/ddev-ms-devtunnel/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/atj4me/ddev-ms-devtunnel/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/atj4me/ddev-ms-devtunnel)](https://github.com/atj4me/ddev-ms-devtunnel/commits)
[![release](https://img.shields.io/github/v/release/atj4me/ddev-ms-devtunnel)](https://github.com/atj4me/ddev-ms-devtunnel/releases/latest)

# DDEV Microsoft Dev Tunnels (devtunnel) <!-- omit in toc -->

- [Overview](#overview)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Advanced Customization](#advanced-customization)
- [Components of the Repository](#components-of-the-repository)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Overview

Microsoft Dev Tunnels (`devtunnel`) provides secure, authenticated exposure of local services to the internet using the Microsoft Dev Tunnels relay service.

This add-on integrates `devtunnel` into your [DDEV](https://ddev.com) project. Run `ddev devtunnel share` to host a tunnel on demand and optionally allow anonymous access for public sharing.

Learn more: https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/

## Use Cases

This add-on is particularly useful for:

- **Cross-device testing**: Test your sites on phones, tablets, or other devices without being on the same Wi-Fi network
- **Stable webhook URLs**: To obtain a stable URI use a persistent Dev Tunnel (`devtunnel create`) or use the relay URI provided when hosting.
- **Team collaboration**: Share your development environment with team members to show work in progress
- **Remote development**: Access your local development sites securely from anywhere

## Prerequisites

- No host-side Tunnels CLI is strictly required: the add-on's `web-build/Dockerfile.ms-devtunnel` installs the `devtunnel` CLI into the web container.
- For private tunnels you must authenticate the `devtunnel` CLI inside the web container (interactive or device-code). Run:

```bash
# interactive
ddev devtunnel login

# or device-code (useful for headless/CI)
DT_DEVICE_LOGIN=1 ddev devtunnel login -d
```

- If the web container cannot open a browser and `devtunnel` falls back to the device-code flow, the `ddev devtunnel login` wrapper will show host-friendly instructions, attempt to open the device login page on your host, and copy the device code to the clipboard when possible.

- The wrapper defaults to non-interactive device-code login (no GUI required). Use `ddev devtunnel login --interactive` to force interactive login when you have a GUI-capable container or host. You no longer need to set `DT_DEVICE_LOGIN` in headless or CI environments.

- To allow anonymous (public) access, use `--public` / `--allow-anonymous` when running `ddev devtunnel share`.

(See: https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/ for details.)

## Installation

```bash
ddev add-on get atj4me/ddev-ms-devtunnel
ddev restart
```


To launch your project's Dev Tunnels URL in your browser:
```bash
ddev devtunnel launch
```

To get your project's Dev Tunnels URL:
```bash
ddev devtunnel url
```


When hosted, Dev Tunnels exposes your site at a relay URI such as: `https://<tunnelid>-<port>.<region>.devtunnels.ms/` (use `devtunnel create` for persistent tunnels).

### Configure Privacy (Optional)

By default, the project doesn't host a Dev Tunnel. To host your project privately (requires `devtunnel` login in the web container):

`ddev devtunnel share`

To make your project publicly accessible (allow anonymous access):

```bash
ddev devtunnel share --public
```

To stop hosting the tunnel:

```bash
ddev devtunnel stop
```

Note about DDEV's `ddev share` providers

- Important: this add‑on intentionally does **not** install a host‑level `ddev share` provider. `devtunnel` is installed inside the `web` container and exposed via the `ddev devtunnel` wrapper only.
- Rationale: keeping the `devtunnel` CLI container‑side avoids requiring host binaries and preserves the add‑on’s portability and security model.

If you need a host‑side provider for your own workflow, create it locally in your project’s `.ddev/share-providers/` — the add‑on will not add such a provider automatically.

## Usage

Access all `devtunnel` CLI commands (https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/cli-commands) plus helpful shortcuts:

| Command | Description |
| ------- | ----------- |
| `ddev devtunnel launch [--public]` | Host and launch your project's Dev Tunnels URL in your browser (`--public` allows anonymous access) |
| `ddev devtunnel share [--public] [--port=<port>]` | Start hosting your project via Dev Tunnels (`--public` allows anonymous access, `--port` sets the local port) |
| `ddev devtunnel stop` | Stop hosting and terminate devtunnel host processes |
| `ddev devtunnel stat` | Show devtunnel user/login status |
| `ddev devtunnel url` | Get your project's Dev Tunnels URL (if hosted) |
| `ddev devtunnel login` | Authenticate with devtunnel |
| `ddev devtunnel <any devtunnel command>` | Run any `devtunnel` CLI command in the web container |

**Notes:**
- The add-on uses the port configured in `DDEV_ROUTER_HTTP_PORT` (default: `80`). To use a custom port, add `--port=<port number>` to your command. Example: `ddev devtunnel share --port=8025 --public` exposes the Mailpit service to the internet. Only ports inside the `web` service are supported.
- The script now checks authentication before running commands and provides clearer error messages and guidance for login.
- Proxy/funnel status and reset are handled automatically to avoid port conflicts and stale configurations.

## Advanced Commands

Use the native `devtunnel` CLI for advanced hosting and access-control operations. The add-on provides convenient shortcuts (`ddev devtunnel share`, `ddev devtunnel stop`, `ddev devtunnel url`) for common workflows.

Examples:

```bash
# Host a local server on port 3000 (foreground)
ddev devtunnel host -p 3000

# Host in background via the wrapper (preferred)
ddev devtunnel share --port=3000

# Allow anonymous (public) access
ddev devtunnel share --public
```

For port configuration and access control (tokens, tenants, orgs) use the `devtunnel` subcommands (`devtunnel token`, `devtunnel access`, `devtunnel port`). See: https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/cli-commands



## Troubleshooting


If you get an error while running the share command, check your authentication status:
- Make sure your `TS_AUTHKEY` environment variable is set and valid.
- Run `ddev devtunnel user login` (or `ddev devtunnel login`) to authenticate interactively if needed.
- If you encounter port conflicts or stale proxy/funnel handlers, the script will attempt to reset and retry automatically.
If problems persist, try logging out using `ddev devtunnel user logout` and then rerun your command (`ddev devtunnel share`, `ddev devtunnel launch`, or your custom command).


## Components of the Repository


- **`install.yaml`** – DDEV add-on installation manifest, copies files and provides setup instructions
- **`docker-compose.ms-devtunnel.yaml`** – Docker Compose override for the add-on (Dev Tunnels does not require extra volumes by default)
- **`config.ms-devtunnel.yaml`** – Main YAML configuration for ms-devtunnel add-on
- **`commands/host/devtunnel`** – Bash wrapper for DDEV host, provides `devtunnel` CLI access and shortcuts
- **`web-build/Dockerfile.ms-devtunnel`** – Dockerfile that installs the `devtunnel` CLI into the web container
- **`tests/test.bats`** – Automated BATS test script for verifying Dev Tunnels integration
- **`tests/testdata/`** – Test data for automated tests
- **`.github/workflows/tests.yml`** – GitHub Actions workflow for automated testing
- **`.github/ISSUE_TEMPLATE/` and `PULL_REQUEST_TEMPLATE.md`** – Contribution and PR templates

## Testing

This add-on includes automated tests to ensure that the Dev Tunnels integration works correctly inside a DDEV environment.

To run tests locally:

```bash
bats tests/test.bats
```

Tests also run automatically in GitHub Actions on every push.


## Contributing

Contributions are welcome! If you have suggestions, bug reports, or feature requests, please:

1. Fork the repository.
2. Create a new branch.
3. Make your changes.
4. Submit a pull request.


## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

---

Maintained by [@atj4me](https://github.com/atj4me) 🚀

Let me know if you want any tweaks! 🎯
