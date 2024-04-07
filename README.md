# firefox
Build Firefox with patches and a custom pdf.js version on Linux and macOS.

## Linux
1. Build in podman for your distro:
```bash
# Ubuntu
podman build -f docker/ubuntu.dockerfile -t firefox-builder:ubuntu &&
    podman run --rm -v $PWD:/firefox firefox-builder:ubuntu
# Arch
podman build -f docker/archlinux.dockerfile -t firefox-builder:archlinux &&
    podman run --rm -v $PWD:/firefox firefox-builder:archlinux
```

2. Install runtime dependencies
```bash
sudo apt install libdbus-glib1.0-cil
sudo pacman -S dbus-glib
```

## macOS
TODO


## Development notes for mozilla-unified
Build setup outside container on Arch:
```bash
rustup default 1.74.0
rustup target add wasm32-unknown-unknown

paru -S git-cinnabar
sudo pacman -S wasi-compiler-rt wasi-libc wasi-libc++ wasi-libc++abi cbindgen
```

Useful commands:
```bash
# (clean)
./mach clobber

# Generate compile_commands.json
./mach build-backend --backend=CompileDB

# Custom user.js can be put in ./my_profile
./mach run -n -- --profile ./my_profile
```
