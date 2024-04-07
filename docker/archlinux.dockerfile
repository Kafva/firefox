FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    clang \
    git \
    python \
    curl \
    dbus-glib \
    gtk3 \
    pulseaudio \
    mercurial \
    zip \
    make
    ruby

WORKDIR /firefox
VOLUME /firefox

RUN git config --global user.email "builder@mozilla.org"
RUN git config --global user.name "builder"

ENTRYPOINT ["make", "clean", "build"] 
