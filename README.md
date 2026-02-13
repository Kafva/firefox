# firefox
Build Firefox with patches and a custom pdf.js version on Linux and macOS. To
use your own patches, place them under `./patches` before starting the build.
Configuration variables for the build are set in `config.mk`.

To build for all supported platforms:
```bash
make all
```

## Linux
Linux targets can be built from both Linux and macOS via containers.

```bash
make $DISTRO
```

Supported `DISTRO` values:
* `ubuntu`
* `archlinux`

The `TARGET=` variable controls the target architecture, only
`x86_64-linux-gnu` is tested to work for Linux.

## macOS
The macOS target can only be built from a macOS host. The default configuration
in the repository compiles for arm64, cross-compiling from a x86_64 machine
should work. You need at least 64 GB of disk. Setup from a fresh install:

1. Setup Xcode, can be downloaded from
   [here](https://xcodereleases.com/) (Apple ID required)
```bash
xcode-select --install

(cd /Applications && xip --expand ~/Downloads/Xcode_*.xip)

sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license
```

2. Install build dependencies
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew bundle install --file conf/Brewfile
./scripts/rustup.sh
```

3. Build
```bash
make macos
```

## Tips
The builtin pdf.js viewer in Firefox can also be patched from a finished build,
you do not need to build from source.
**NB** This can break other extensions in unexpected ways, e.g. the
autocompletion for the Vimium omnibar.

```bash
# Build pdf.js for Firefox
npx gulp mozcentral

# Patch the omni.ja of your existing installation with your build output
(cd build/mozcentral/browser &&
    ln -fns extensions chrome &&
    zip "/usr/lib/firefox/omni.ja" 'chrome/*')
```

To reuse the same profile after downgrading Firefox, delete
`~/.mozilla/firefox/$PROFILE/compatibility.ini`.

`console.log()` output from internal Javascript in Firefox should be visible by
default on stdout, `./mach run` is not doing any extra magic for this to
happen, it is part of the binary itself. To run with additional Javascript
logging use `MOZ_LOG=console:5`.
