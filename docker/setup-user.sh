#!/usr/bin/env bash
set -e

case "$(uname)" in
Darwin)
    TARGET=${TARGET:-"aarch64-apple-darwin"} ;;
Linux)
    TARGET=${TARGET:-"x86_64-unknown-linux-gnu"} ;;
esac

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
bash -s -- -y \
           -t wasm32-unknown-unknown \
           --default-host $TARGET \
           --default-toolchain stable

"$HOME/.cargo/bin/cargo" install cbindgen git-cinnabar

git -C mozilla-unified config user.email "builder@mozilla.org"
git -C mozilla-unified config user.name "builder"
git -C mozilla-unified config remote.origin.prune true
git -C mozilla-unified config fetch.prune true
