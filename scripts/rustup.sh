#!/usr/bin/env bash
set -e

#
# https://firefox-source-docs.mozilla.org/writing-rust-code/update-policy.html
#
VERSION=1.86

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
bash -s -- -y \
           -t wasm32-unknown-unknown \
           --default-toolchain $VERSION

if [ $(uname) = Darwin ]; then
    "$HOME/.cargo/bin/rustup" target add aarch64-apple-darwin
fi
