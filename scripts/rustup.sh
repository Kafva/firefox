#!/usr/bin/env bash
set -e

RUST_VERSION=$(sed -nE 's/RUST_VERSION *= *(.*)/\1/p' config.mk)

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
bash -s -- -y \
           -t wasm32-unknown-unknown \
           --default-toolchain $RUST_VERSION

if [ "$(uname)" = Darwin ]; then
    "$HOME/.cargo/bin/rustup" target add aarch64-apple-darwin
fi
