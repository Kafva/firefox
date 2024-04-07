FROM docker.io/ubuntu:22.04

ARG LOCAL_UID=1000
ARG LOCAL_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lsb-release \
    build-essential \
    clang \
    curl \
    git \
    libdbus-glib-1-dev \
    libgtk-3-dev \
    libpulse-dev \
    libxt-dev \
    mercurial \
    python3 \
    zip \
    make \
    ruby \
    nodejs \
    npm \
    rsync

# For building pdf.js
RUN npm install -g gulp-cli

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${LOCAL_GID} _builder_podman
RUN useradd --uid ${LOCAL_UID} --gid ${LOCAL_GID} --create-home --shell /bin/bash builder
USER builder

# TODO use newer nodejs

# TODO handle interactive prompts from bootstrap.sh...
RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

ENTRYPOINT ["make", "clean", "build"]
