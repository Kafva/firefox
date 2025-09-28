FROM docker.io/archlinux:latest

ARG BUILDER_UID=${BUILDER_UID:-1000}
ARG BUILDER_GID=${BUILDER_GID:-1000}

# Update keyring
RUN pacman-key --init && \
    pacman --noconfirm -Syu && \
    pacman --noconfirm -Sy archlinux-keyring && \
    pacman --noconfirm -Syu
# Install packages
RUN pacman -Syu --noconfirm base-devel \
                            clang \
                            nodejs \
                            npm \
                            git \
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

# Create build user with matching UID/GID to outside user
RUN groupadd -g ${BUILDER_GID} _builder || :
RUN useradd --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --shell /bin/bash builder
# Make it easy to install more packages for debugging
RUN echo "builder ALL=NOPASSWD: ALL" > /etc/sudoers.d/builder
USER builder
WORKDIR /home/builder/firefox
VOLUME /home/builder/firefox

# Install rust
COPY ./scripts/rustup.sh .
RUN ./rustup.sh

RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"
RUN git config --global remote.origin.prune true
RUN git config --global fetch.prune true
RUN git config --global commit.gpgsign false

ENTRYPOINT ["make", "unpatch", "build"]
