# firefox
Build Firefox with patches and a custom pdf.js version on Linux and macOS. To
use your own patches, place them under `./patches` before starting the build.
Configuration variables for the build are set in `config.mk` and the
`mozconfig` files under `conf`.

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
The default configuration in the repository compiles for arm64, cross-compiling
from a x86_64 machine should work. You need at least 64 GB of disk. Setup from
a fresh install:

1. Setup Xcode, can be downloaded from
   [here](https://xcodereleases.com/) (Apple ID required)
```bash
xcode-select --install

# XXX: Newer Xcode version may be required...
(cd /Applications && xip --expand ~/Downloads/Xcode_15.3.xip)

sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license
```

2. Install build dependencies
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew bundle install --file conf/Brewfile

# Setup rust
./scripts/rustup.sh

# For building pdf.js
npm install -g gulp-cli
```

3. Build
```bash
make
```

## Tips
The builtin pdf.js viewer in Firefox can also be patched from a finished build,
you do not need to build from source.
**NB** This can break other extensions in unexpected ways, e.g. the
autocompletion for the Vimium omnibar.

```bash
# Build pdf.js for Firefox
gulp mozcentral

# Patch the omni.ja of your existing installation with your build output
(cd build/mozcentral/browser &&
    ln -fns extensions chrome &&
    zip "/usr/lib/firefox/omni.ja" 'chrome/*')
```

Useful commands for the mozilla-unified build system:
```bash
# (clean)
./mach clobber

# Generate compile_commands.json
./mach build-backend --backend=CompileDB

# Custom user.js can be put in ./my_profile
./mach run -n -- --profile ./my_profile
```

To reuse the same profile after downgrading Firefox, delete
`~/.mozilla/firefox/$PROFILE/compatibility.ini`.

