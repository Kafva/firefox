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
    nasm \
    mercurial \
    m4 \
    libdbus-glib-1-dev \
    libx11-xcb-dev \
    libasound2-dev \
    libgtk-3-dev \
    libpulse-dev \
    libxt-dev \
    python3 \
    zip \
    make \
    ruby \
    ccache \
    lld \
    rsync

# The nodejs version in 22.04 is to old
RUN curl "https://nodejs.org/dist/v20.12.1/node-v20.12.1-linux-x64.tar.xz" | tar -xJf - -C /usr --strip-components=1

# For building pdf.js
RUN npm install -g gulp-cli

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${BUILDER_GID} _builder_podman || :
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
USER builder
WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

# Setup the builder user
COPY setup-user.sh .
RUN ./setup-user.sh

ENTRYPOINT ["make", "clean", "build"]
