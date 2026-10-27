#!/bin/bash
# Installs the Julia and Lean toolchains for cloud sessions; idempotent.
# Lean: elan's self-update check reads GitHub's "latest release" page, which the session proxy
# refuses, so the pinned toolchain is unpacked straight into elan's toolchain directory.
# Keep LEAN_VERSION equal to lean-toolchain.
set -euo pipefail

JULIA_VERSION=1.13.3
JULIA_SHA256=5c61cb4b40332cb5a3504e7779e2f5dac093caa4a1116ded19f01413f85c63e4
ELAN_VERSION=4.1.2
LEAN_VERSION=4.29.0

opt="$HOME/.local/opt"
mkdir -p "$opt" "$HOME/.local/bin"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ ! -x "$opt/julia-$JULIA_VERSION/bin/julia" ]; then
  curl -sSfL -o "$tmp/julia.tar.gz" \
    "https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_VERSION%.*}/julia-$JULIA_VERSION-linux-x86_64.tar.gz"
  echo "$JULIA_SHA256  $tmp/julia.tar.gz" | sha256sum -c -
  tar xzf "$tmp/julia.tar.gz" -C "$opt"
fi
ln -sf "$opt/julia-$JULIA_VERSION/bin/julia" "$HOME/.local/bin/julia"

if [ ! -x "$HOME/.elan/bin/elan" ]; then
  curl -sSfL -o "$tmp/elan.tar.gz" \
    "https://github.com/leanprover/elan/releases/download/v$ELAN_VERSION/elan-x86_64-unknown-linux-gnu.tar.gz"
  tar xzf "$tmp/elan.tar.gz" -C "$tmp"
  "$tmp/elan-init" -y --default-toolchain none --no-modify-path
fi

tc="$HOME/.elan/toolchains/leanprover--lean4---v$LEAN_VERSION"
if [ ! -x "$tc/bin/lean" ]; then
  curl -sSfL -o "$tmp/lean.zip" \
    "https://github.com/leanprover/lean4/releases/download/v$LEAN_VERSION/lean-$LEAN_VERSION-linux.zip"
  unzip -q "$tmp/lean.zip" -d "$tmp"
  mkdir -p "$HOME/.elan/toolchains"
  mv "$tmp/lean-$LEAN_VERSION-linux" "$tc"
fi
for b in elan lean lake; do ln -sf "$HOME/.elan/bin/$b" "$HOME/.local/bin/$b"; done
