FROM docker.io/archlinux:latest

# TODO
ARG BUILDER_UID=${BUILDER_UID:-1000}
ARG BUILDER_GID=${BUILDER_GID:-1000}

RUN pacman -Syu --noconfirm base-devel \
                            clang \
                            rustup \
                            nodejs \
                            npm \
                            git \
                            python \
                            curl \
                            dbus-glib \
                            gtk3 \
                            pulseaudio \
                            zip \
                            make \
                            ruby \
                            ccache \
                            lld \
                            rsync \
                            wasi-compiler-rt \
                            wasi-libc wasi-libc++ \
                            wasi-libc++abi

RUN cargo install cbindgen git-cinnabar


# For building pdf.js
RUN npm install -g gulp-cli

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${BUILDER_GID} _builder_podman
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
USER builder
WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

ENTRYPOINT ["make", "clean", "build"]

