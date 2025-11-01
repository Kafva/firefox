FROM docker.io/ubuntu:24.04

ARG BUILDER_UID=${BUILDER_UID:-1000}
ARG BUILDER_GID=${BUILDER_GID:-1000}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lsb-release \
    sudo \
    build-essential \
    clang \
    curl \
    git \
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
    rsync

# Cleanup cache
RUN rm -rf /var/lib/apt/lists/*

# HINT: `./mach build` dies with: No such file or directory: '/usr/sbin/*'
RUN ln -fns /usr/bin/ccache /usr/sbin/ccache
RUN ln -fns /usr/bin/make /usr/sbin/make

# The nodejs version in 24.04 is too old
RUN curl "https://nodejs.org/dist/v20.12.1/node-v20.12.1-linux-x64.tar.xz" | tar -xJf - -C /usr --strip-components=1

# Create build user with matching UID/GID to outside user
RUN userdel ubuntu
RUN groupadd -g ${BUILDER_GID} _builder || :
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
# Make it easy to install more packages for debugging
RUN echo "builder ALL=NOPASSWD: ALL" > /etc/sudoers.d/builder
USER builder
WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

# Install rust
COPY ./config.mk .
COPY ./scripts/rustup.sh .
RUN ./rustup.sh

# The cbindgen version in the Ubuntu repo is too old, install it from source
RUN "$HOME/.cargo/bin/cargo" install cbindgen

RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"
RUN git config --global remote.origin.prune true
RUN git config --global fetch.prune true
RUN git config --global commit.gpgsign false

ENTRYPOINT ["make", "unpatch", "build"]
