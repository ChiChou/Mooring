#!/bin/bash
#
# setup.sh — Download latest nightly macOS builds from libimobiledevice
# GitHub Actions and prepare them for bundling.
#
# Dependencies: gh (GitHub CLI, authenticated), jq, tar, install_name_tool
#
# Usage: ./setup.sh
#
# All dylib load paths are patched with install_name_tool to use
# @executable_path/../lib/ so no DYLD_LIBRARY_PATH is needed at runtime.
#
# Licenses: All three libraries are LGPL-2.1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_DIR="${SCRIPT_DIR}/../.cache/libimobiledevice"
WORK_DIR="$(mktemp -d)"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

log() { echo "==> $*"; }

# Get the latest successful macOS build run ID for a repo.
latest_run_id() {
    gh run list \
        --repo "$1" \
        --workflow build \
        --branch master \
        --status success \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId'
}

# Download and extract the macOS artifact from a run.
download_artifact() {
    local repo="$1" run_id="$2" name="$3" dest="$4"
    log "Downloading $name from $repo (run $run_id)"
    gh run download "$run_id" --repo "$repo" --name "$name" --dir "$dest"
    local tarball
    tarball="$(find "$dest" -name '*.tar' -maxdepth 1 | head -1)"
    if [[ -n "$tarball" ]]; then
        tar xf "$tarball" -C "$dest"
        rm "$tarball"
    fi
}

# ── fetch artifacts ──────────────────────────────────────────────────────────

REPOS=(
    "libimobiledevice/libplist            libplist-latest_macOS"
    "libimobiledevice/libimobiledevice-glue libimobiledevice-glue-latest_macOS"
    "libimobiledevice/libusbmuxd          libusbmuxd-latest_macOS"
    "libimobiledevice/libimobiledevice    libimobiledevice-latest_macOS"
)

for entry in "${REPOS[@]}"; do
    repo="$(echo "$entry" | awk '{print $1}')"
    artifact="$(echo "$entry" | awk '{print $2}')"
    run_id="$(latest_run_id "$repo")"
    if [[ -z "$run_id" ]]; then
        echo "ERROR: No successful build found for $repo" >&2
        exit 1
    fi
    download_artifact "$repo" "$run_id" "$artifact" "$WORK_DIR/$artifact"
done

# ── assemble bundle ─────────────────────────────────────────────────────────

log "Assembling bundle at $BUNDLE_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/bin" "$BUNDLE_DIR/lib"

# Collect binaries
cp "$WORK_DIR/libusbmuxd-latest_macOS/usr/local/bin/iproxy"     "$BUNDLE_DIR/bin/"
cp "$WORK_DIR/libimobiledevice-latest_macOS/usr/local/bin/idevice_id" "$BUNDLE_DIR/bin/"

# Collect all non-static dylibs from each artifact
for artifact_dir in "$WORK_DIR"/*/usr/local/lib; do
    find "$artifact_dir" -maxdepth 1 -name '*.dylib' ! -name '*.a' -exec cp {} "$BUNDLE_DIR/lib/" \;
done

# ── patch load paths ────────────────────────────────────────────────────────

# Build list of all bundled dylib filenames
DYLIB_NAMES=()
for f in "$BUNDLE_DIR/lib"/*.dylib; do
    DYLIB_NAMES+=("$(basename "$f")")
done

patch_binary() {
    local bin="$1"
    for dylib in "${DYLIB_NAMES[@]}"; do
        install_name_tool \
            -change "/usr/local/lib/$dylib" "@executable_path/../lib/$dylib" \
            "$bin" 2>/dev/null || true
    done
}

log "Patching load paths in binaries"
for bin in "$BUNDLE_DIR/bin"/*; do
    patch_binary "$bin"
done

log "Patching load paths in dylibs"
for dylib in "$BUNDLE_DIR/lib"/*.dylib; do
    name="$(basename "$dylib")"
    install_name_tool -id "@executable_path/../lib/$name" "$dylib" 2>/dev/null || true
    patch_binary "$dylib"
done

# ── verify ───────────────────────────────────────────────────────────────────

log "Verifying bundle"
FAIL=0
for bin in "$BUNDLE_DIR/bin"/* "$BUNDLE_DIR/lib"/*.dylib; do
    if otool -L "$bin" | grep -q '/usr/local/lib/'; then
        echo "ERROR: $bin still references /usr/local/lib/" >&2
        otool -L "$bin" | grep '/usr/local/lib/' >&2
        FAIL=1
    fi
done

if [[ "$FAIL" -eq 1 ]]; then
    echo "Bundle verification FAILED" >&2
    exit 1
fi

log "Done. Bundle contents:"
find "$BUNDLE_DIR" -type f | sort | while read -r f; do
    printf "  %s\n" "${f#$BUNDLE_DIR/}"
done
