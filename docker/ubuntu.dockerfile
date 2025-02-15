FROM docker.io/ubuntu:22.04

ARG BUILDER_UID=${BUILDER_UID:-1000}
ARG BUILDER_GID=${BUILDER_GID:-1000}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lsb-release \
    build-essential \
    clang \
    curl \
    git \
    mercurial \
    nasm \
    zstd \
    m4 \
    libdbus-glib-1-dev \
    libx11-xcb-dev \
    libasound2-dev \
    libgtk-3-dev \
    libpulse-dev \
    libxt-dev \
    python3 \
    python3-dev \
    python3-pip \
    zip \
    make \
    ruby \
    ccache \
    lld \
    rsync && rm -rf /var/lib/apt/lists/*

# The nodejs version in 22.04 is too old
RUN curl "https://nodejs.org/dist/v20.12.1/node-v20.12.1-linux-x64.tar.xz" | tar -xJf - -C /usr --strip-components=1

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

# The cbindgen version in the Ubuntu repo is too old, install it from source
RUN "$HOME/.cargo/bin/cargo" install cbindgen

RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

ENTRYPOINT ["make", "unpatch", "build"]
