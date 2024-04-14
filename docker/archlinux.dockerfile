FROM docker.io/archlinux:latest

ARG BUILDER_UID=${BUILDER_UID:-1000}
ARG BUILDER_GID=${BUILDER_GID:-1000}

RUN pacman -Syu --noconfirm base-devel \
                            clang \
                            nodejs \
                            npm \
                            git \
                            mercurial \
                            python \
                            python-pip \
                            curl \
                            dbus-glib \
                            gtk3 \
                            pulseaudio \
                            zip \
                            make \
                            ruby \
                            ccache \
                            cbindgen \
                            lsb-release \
                            llvm \
                            lld \
                            rsync \
                            unzip \
                            nasm \
                            wasi-compiler-rt \
                            wasi-libc wasi-libc++ \
                            wasi-libc++abi && pacman -Scc --noconfirm

# For building pdf.js
RUN npm install -g gulp-cli

# Install git-cinnabar
RUN curl 'https://raw.githubusercontent.com/glandium/git-cinnabar/master/download.py' | \
    python3 - && install -v git-* /usr/bin && rm git-cinnabar git-remote-hg

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${BUILDER_GID} _builder_podman || :
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
USER builder
WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

# Install rust
COPY ./scripts/rustup.sh .
RUN ./rustup.sh

RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

ENTRYPOINT ["make", "clean", "build"]
