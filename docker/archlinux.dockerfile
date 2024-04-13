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
                            curl \
                            dbus-glib \
                            gtk3 \
                            pulseaudio \
                            zip \
                            make \
                            ruby \
                            ccache \
                            lsb-release \
                            lld \
                            rsync \
                            wasi-compiler-rt \
                            wasi-libc wasi-libc++ \
                            wasi-libc++abi

# For building pdf.js
RUN npm install -g gulp-cli

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${BUILDER_GID} _builder_podman || :
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
USER builder
WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

# Setup the builder user
COPY ./scripts/setup-user.sh .
RUN ./setup-user.sh

RUN echo "export PATH=\$PATH:$HOME/.cargo/bin" >> ~/.bashrc
RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

ENTRYPOINT ["make", "clean", "build"]

