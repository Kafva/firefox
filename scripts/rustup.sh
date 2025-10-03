#!/usr/bin/env bash
set -e

# FIREFOX_NIGHTLY_143_END does not compile with 1.90, stay on 1.89
# |  help: the same lifetime is referred to in inconsistent ways,
# |  making the signature confusing, help: use `'_` for type paths
VERSION=1.89

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
bash -s -- -y \
           -t wasm32-unknown-unknown \
           --default-toolchain $VERSION

if [ $(uname) = Darwin ]; then
    "$HOME/.cargo/bin/rustup" target add aarch64-apple-darwin
fi
