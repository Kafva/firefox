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
You need at least 64 GB of disk. Setup from a fresh install:

0. Install Xcode command line tools: `xcode-select --install`
1. Install brew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. Install Xcode (tested with 15.3 on Ventura), can be downloaded from [here](https://xcodereleases.com/)
```bash
(cd /Applications && xip --expand ~/Downloads/Xcode_15.3.xip)

sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license
```
3. Install build dependencies (some basic build packages are not listed)
```bash
brew install git-cinnabar
```


## Development notes for mozilla-unified
Useful commands:
```bash
# (clean)
./mach clobber

# Generate compile_commands.json
./mach build-backend --backend=CompileDB

# Custom user.js can be put in ./my_profile
./mach run -n -- --profile ./my_profile
```
