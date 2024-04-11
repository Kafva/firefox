# firefox
Build Firefox with patches and a custom pdf.js version on Linux and macOS.

## Linux
1. Build in podman for your distro (ubuntu or archlinux):
```bash
make $DISTRO
```

2. Install runtime dependencies
```bash
sudo apt install libdbus-glib1.0-cil
sudo pacman -S dbus-glib
```

## macOS
This guide describes how to cross compile from x86_64 to arm64, I recommend
using [quickemu](https://github.com/quickemu-project/quickemu) to create the
build machine if you do not have a powerful x86_64 mac lying around.


## Development notes for mozilla-unified
Useful commands:
```bash
# For working outside the container on Arch
paru -S git-cinnabar

# (clean)
./mach clobber

# Generate compile_commands.json
./mach build-backend --backend=CompileDB

# Custom user.js can be put in ./my_profile
./mach run -n -- --profile ./my_profile
```
