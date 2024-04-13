#!/usr/bin/env bash
set -e

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
bash -s -- -y \
           -t wasm32-unknown-unknown \
           --default-toolchain stable

if [ $(uname) = Darwin ]; then
    "$HOME/.cargo/bin/rustup" target add aarch64-apple-darwin
fi
