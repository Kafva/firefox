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
    libdbus-glib-1-dev \
    libasound2-dev \
    libgtk-3-dev \
    libpulse-dev \
    libxt-dev \
    mercurial \
    python3 \
    zip \
    make \
    ruby \
    ccache \
    lld \
    rsync \
    cbindgen

# Install rust
WORKDIR /tmp
RUN curl -sO "https://static.rust-lang.org/dist/rust-1.77.2-x86_64-unknown-linux-gnu.tar.xz"
RUN curl -sO "https://static.rust-lang.org/dist/rust-1.77.2-x86_64-unknown-linux-gnu.tar.xz.asc"
RUN curl -s "https://static.rust-lang.org/rust-key.gpg.ascii" | gpg --import -
RUN gpg --verify "rust-1.77.2-x86_64-unknown-linux-gnu.tar.xz.asc"
RUN tar -Jxf rust-1.77.2-x86_64-unknown-linux-gnu.tar.xz
RUN (cd "rust-1.77.2-x86_64-unknown-linux-gnu" && ./install.sh)
RUN rm -r "rust-1.77.2-x86_64-unknown-linux-gnu" \
          "rust-1.77.2-x86_64-unknown-linux-gnu.tar.xz" \
          "rust-1.77.2-x86_64-unknown-linux-gnu.tar.xz.asc"

# The nodejs version in 22.04 is to old
RUN curl "https://nodejs.org/dist/v20.12.1/node-v20.12.1-linux-x64.tar.xz" | tar -xJf - -C /usr --strip-components=1

# For building pdf.js
RUN npm install -g gulp-cli

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${BUILDER_GID} _builder_podman
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
USER builder

# TODO handle interactive prompts from bootstrap.sh...
RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

ENTRYPOINT ["make", "clean", "build"]
