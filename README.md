# installs

A collection of small, self-contained shell scripts that automate tedious or
repetitive install processes — the kind of setup you'd otherwise copy-paste from
a docs page every time you spin up a new machine.

Each script:

- is **standalone** — no shared library, just run it;
- **auto-detects** the OS and architecture where it makes sense;
- **fetches the latest stable version** rather than hardcoding one;
- **verifies downloads** against official checksums before installing;
- is **idempotent** — re-running is safe and skips work that's already done;
- is **configurable** via environment variables, with sensible defaults.

## Scripts

| Script          | Installs | Default install path | Notes |
|-----------------|----------|----------------------|-------|
| `install-go.sh` | The latest stable [Go](https://go.dev) toolchain | `/usr/local/go` | Verifies SHA-256, skips if already current |

### `install-go.sh`

Downloads, verifies, and installs the latest stable Go release for your
OS/arch into `/usr/local/go`.

```bash
./install-go.sh
```

**Install directly from GitHub** (no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/SalemCode8/installs/main/install-go.sh | bash
```

Pass env vars before the pipe to configure it:

```bash
GO_VERSION=1.22.4 curl -fsSL https://raw.githubusercontent.com/SalemCode8/installs/main/install-go.sh | bash
```

> Piping into `bash` runs the script unreviewed. If you'd rather inspect it
> first, download it, read it, then run it:
>
> ```bash
> curl -fsSL -O https://raw.githubusercontent.com/SalemCode8/installs/main/install-go.sh
> less install-go.sh && bash install-go.sh
> ```

**Environment variables**

| Variable           | Default        | Description |
|--------------------|----------------|-------------|
| `GO_VERSION`       | latest stable  | Version to install, e.g. `1.22.4` or `go1.22.4`. Empty resolves the latest from go.dev |
| `GO_INSTALL_DIR`   | `/usr/local`   | Install prefix; Go unpacks to `$GO_INSTALL_DIR/go` |
| `GO_DOWNLOAD_DIR`  | `~/Downloads`  | Where the tarball is downloaded (removed after install) |

**Examples**

```bash
# Pin a specific version instead of latest
GO_VERSION=1.22.4 ./install-go.sh

# Install into your home directory (no sudo needed)
GO_INSTALL_DIR=$HOME/.local ./install-go.sh

# Use a different scratch dir for the download
GO_DOWNLOAD_DIR=/tmp ./install-go.sh
```

**Behavior**

- Detects OS (Linux, macOS) and arch (amd64, arm64, armv6l, 386).
- Installs `GO_VERSION` if set, otherwise queries `go.dev/VERSION` for the
  latest stable version — never hardcoded.
- Skips entirely if that exact version is already installed; reports an
  upgrade otherwise.
- Verifies the download's SHA-256 against the official `.sha256` file before
  touching the install dir.
- Uses `sudo` only when the install dir isn't writable.
- Deletes the downloaded archive after a successful install. A failed download
  or checksum leaves the partial file in place for inspection.
- Prints a `PATH` hint if `go` isn't already on your `PATH`.

## Conventions for new scripts

When adding an installer, keep the house style so every script behaves
predictably:

- **Name** it `install-<tool>.sh` and `chmod +x` it.
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Provide `err()` / `info()` helpers for consistent, prefixed output.
- Check for required commands up front and fail with a clear message.
- Expose paths as `<TOOL>_INSTALL_DIR` / `<TOOL>_DOWNLOAD_DIR` env vars with
  defaults (`/usr/local` and `~/Downloads` are the conventions here).
- Fetch the latest version dynamically; verify checksums/signatures when the
  upstream publishes them.
- Make it idempotent — detect an existing, current install and exit early.
- Only escalate with `sudo` when the target path isn't writable.
- Document the script in the table above and add a short section here.

## Requirements

Most scripts rely on common tooling: `curl`, `tar`, `sha256sum`, and a POSIX
shell. Each script checks for what it needs and tells you if something's
missing.
