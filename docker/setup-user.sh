#!/usr/bin/env bash
set -e

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
bash -s -- -y \
           -t wasm32-unknown-unknown \
           --default-host x86_64-unknown-linux-gnu \
           --default-toolchain stable

echo "export PATH=\$PATH:$HOME/.cargo/bin" >> ~/.bashrc
"$HOME/.cargo/bin/cargo" install cbindgen git-cinnabar

git config --global user.email "builder@mozilla.org"
git config --global user.name "builder"

