#!/usr/bin/env bash
#
# install-go.sh — Download and install the latest stable Go release.
#
# Detects OS/arch, fetches the latest version from go.dev, verifies the
# download against the official checksum, and installs into /usr/local/go.
#
# Usage:
#   ./install-go.sh                 # install latest stable into /usr/local
#   GO_VERSION=1.22.4 ./install-go.sh             # install a specific version
#   GO_INSTALL_DIR=$HOME/.local ./install-go.sh   # custom install prefix
#   GO_DOWNLOAD_DIR=$HOME/Downloads ./install-go.sh  # custom download dir
#
set -euo pipefail

# Which Go version to install. Empty means "latest stable" (resolved from
# go.dev). Accepts "1.22.4" or "go1.22.4" — the "go" prefix is optional.
GO_VERSION="${GO_VERSION:-}"

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

# --- Resolve the version to install --------------------------------------
if [ -n "$GO_VERSION" ]; then
    # Normalize: allow "1.22.4" as well as "go1.22.4".
    case "$GO_VERSION" in
        go*) VERSION="$GO_VERSION" ;;
        *)   VERSION="go${GO_VERSION}" ;;
    esac
    info "Using requested version ${VERSION}"
else
    info "Querying go.dev for the latest stable version..."
    VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
    [ -n "${VERSION:-}" ] || err "could not determine latest Go version"
fi

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
    || err "download failed (does ${VERSION} have a published ${OS}-${ARCH} build?)"

# --- Verify checksum ------------------------------------------------------
# go.dev no longer serves a raw "<file>.sha256" (it redirects to an HTML page),
# so pull the official SHA-256 from the download JSON API and match our file.
info "Verifying checksum..."
JSON="$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all')" \
    || err "could not fetch checksum metadata"
EXPECTED="$(printf '%s\n' "$JSON" \
    | grep -A5 "\"filename\": \"${TARBALL}\"," \
    | grep '"sha256":' \
    | head -n1 \
    | grep -oE '[a-f0-9]{64}')"
[ -n "$EXPECTED" ] \
    || err "no published checksum found for ${TARBALL}"
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
