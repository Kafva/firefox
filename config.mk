MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
MOZILLA_UNIFIED_URL := https://github.com/mozilla-firefox/firefox.git
export MOZILLA_UNIFIED_REV ?= FIREFOX_143_0_4_RELEASE

PDF_JS := $(CURDIR)/pdf.js
PDF_JS_URL ?= https://github.com/kafva/pdf.js
PDF_JS_REV ?= 2538a9b889152c278cc519edb40abc35e59000f6

# https://firefox-source-docs.mozilla.org/writing-rust-code/update-policy.html
RUST_VERSION = 1.86

# Target settings
ifneq ($(filter macos,$(MAKECMDGOALS)),)
export TARGET_UNAME := darwin
export DISTRO := macos
export TARGET ?= aarch64-apple-darwin
export LDFLAGS := -L/usr/local/opt/llvm/lib
export CPPFLAGS := -I/usr/local/opt/llvm/include
export PATH := /usr/local/opt/llvm/bin:${PATH}

else ifneq ($(filter ubuntu ubuntu-shell,$(MAKECMDGOALS)),)
export TARGET_UNAME := linux
export DISTRO := ubuntu
export TARGET ?= x86_64-linux-gnu

else ifneq ($(filter archlinux archlinux-shell,$(MAKECMDGOALS)),)
export TARGET_UNAME := linux
export DISTRO := arch
export TARGET ?= x86_64-linux-gnu

else ifeq ($(filter _build all clean distclean patch unpatch release,$(MAKECMDGOALS)),)
$(error Invalid build target)
endif

# Host settings
ifeq ($(shell uname),Linux)
CONTAINER_BUILD = docker buildx build
CONTAINER_RUN = docker run

else ifeq ($(shell uname),Darwin)
CONTAINER_BUILD = container build
CONTAINER_RUN = container run

else
$(error Unsupported host platform)
endif

# Tag for new build
TAG ?= $(shell date '+%Y.%m.%d')

export MOZ_PARALLEL_BUILD ?= $(shell nproc)
# Avoid terminal-notifier call on completion
export MOZ_AUTOMATION = 1

export OUT := $(CURDIR)/out/$(DISTRO)

# Container image name, different tags for different distros
IMAGE_NAME := firefox-builder

# Make sure rust toolchain is found
export PATH := ${HOME}/.cargo/bin:${PATH}

# Extra arguments for clone
export GIT_CLONE_ARGS ?=
