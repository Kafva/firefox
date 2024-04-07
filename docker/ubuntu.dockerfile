FROM docker.io/ubuntu:22.04

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
    rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /firefox
VOLUME /firefox

RUN useradd -ms /bin/bash builder
RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

USER builder

# For building pdf.js
RUN npm install -g gulp-cli

ENTRYPOINT ["make", "clean", "build"] 
