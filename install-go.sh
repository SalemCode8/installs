#!/usr/bin/env bash
#
# install-go.sh — Download and install the latest stable Go release.
#
# Detects OS/arch, fetches the latest version from go.dev, verifies the
# download against the official checksum, and installs into /usr/local/go.
#
# Usage:
#   ./install-go.sh                 # install latest stable into /usr/local
#   GO_INSTALL_DIR=$HOME/.local ./install-go.sh   # custom install prefix
#   GO_DOWNLOAD_DIR=$HOME/Downloads ./install-go.sh  # custom download dir
#
set -euo pipefail

# Where Go gets installed (the archive unpacks to ${INSTALL_DIR}/go).
INSTALL_DIR="${GO_INSTALL_DIR:-/usr/local}"
GO_ROOT="${INSTALL_DIR}/go"

# Where the tarball is downloaded before extraction.
DOWNLOAD_DIR="${GO_DOWNLOAD_DIR:-${HOME}/Downloads}"

err() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# --- Require basic tools --------------------------------------------------
for cmd in curl tar sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || err "required command not found: $cmd"
done

# --- Detect OS ------------------------------------------------------------
case "$(uname -s)" in
    Linux)  OS=linux ;;
    Darwin) OS=darwin ;;
    *)      err "unsupported OS: $(uname -s)" ;;
esac

# --- Detect architecture --------------------------------------------------
case "$(uname -m)" in
    x86_64|amd64)   ARCH=amd64 ;;
    aarch64|arm64)  ARCH=arm64 ;;
    armv6l|armv7l)  ARCH=armv6l ;;
    i386|i686)      ARCH=386 ;;
    *)              err "unsupported architecture: $(uname -m)" ;;
esac

# --- Find the latest stable version --------------------------------------
info "Querying go.dev for the latest stable version..."
VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
[ -n "${VERSION:-}" ] || err "could not determine latest Go version"

# Skip if the requested version is already installed.
if [ -x "${GO_ROOT}/bin/go" ]; then
    CURRENT="$("${GO_ROOT}/bin/go" version | awk '{print $3}')"
    if [ "$CURRENT" = "$VERSION" ]; then
        info "$VERSION is already installed at ${GO_ROOT}. Nothing to do."
        exit 0
    fi
    info "Upgrading ${CURRENT} -> ${VERSION}"
fi

TARBALL="${VERSION}.${OS}-${ARCH}.tar.gz"
URL="https://go.dev/dl/${TARBALL}"

# --- Download to the download dir ----------------------------------------
mkdir -p "$DOWNLOAD_DIR" || err "could not create download dir: $DOWNLOAD_DIR"
ARCHIVE="${DOWNLOAD_DIR}/${TARBALL}"

info "Downloading ${URL}"
info "  -> ${ARCHIVE}"
curl -fSL --progress-bar -o "$ARCHIVE" "$URL" \
    || err "download failed (is ${OS}-${ARCH} a published build?)"

# --- Verify checksum ------------------------------------------------------
info "Verifying checksum..."
EXPECTED="$(curl -fsSL "${URL}.sha256")" \
    || err "could not fetch checksum"
ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
[ "$EXPECTED" = "$ACTUAL" ] \
    || err "checksum mismatch: expected $EXPECTED, got $ACTUAL"

# --- Install --------------------------------------------------------------
# Use sudo only when we lack write permission on the install dir.
SUDO=""
if [ ! -w "$INSTALL_DIR" ]; then
    command -v sudo >/dev/null 2>&1 || err "no write access to $INSTALL_DIR and sudo not available"
    SUDO="sudo"
fi

info "Removing any previous install at ${GO_ROOT}"
$SUDO rm -rf "$GO_ROOT"

info "Extracting to ${INSTALL_DIR}"
$SUDO tar -C "$INSTALL_DIR" -xzf "$ARCHIVE"

info "Removing downloaded archive ${ARCHIVE}"
rm -f "$ARCHIVE"

# --- Report and PATH hint -------------------------------------------------
info "Installed: $("${GO_ROOT}/bin/go" version)"

if ! command -v go >/dev/null 2>&1 || [ "$(command -v go)" != "${GO_ROOT}/bin/go" ]; then
    cat <<EOF

Add Go to your PATH by appending this to your shell profile
(~/.bashrc, ~/.zshrc, or ~/.profile):

    export PATH="\$PATH:${GO_ROOT}/bin"

Then reload your shell or run:  export PATH="\$PATH:${GO_ROOT}/bin"
EOF
fi
