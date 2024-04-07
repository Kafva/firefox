# firefox
Build Firefox with patches and a custom pdf.js version on (Arch) Linux and macOS.

* Basic requirements:
    - python3
    - ruby
    - git-cinnabar

* pdf.js requirements
    - npm
    - gulp-cli


## Linux
```bash
# Build deps
rustup default 1.74.0
rustup target add wasm32-unknown-unknown

paru -S git-cinnabar
sudo pacman -S wasi-compiler-rt wasi-libc wasi-libc++ wasi-libc++abi cbindgen

# Runtime deps
sudo apt install libdbus-glib1.0-cil
sudo pacman -S dbus-glib
```


## Development notes for mozilla-unified
```bash
# (clean)
./mach clobber

# Generate compile_commands.json
./mach build-backend --backend=CompileDB

# Custom user.js can be put in ./my_profile
./mach run -n -- --profile ./my_profile
```
