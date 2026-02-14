MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
MOZILLA_UNIFIED_URL := https://github.com/mozilla-firefox/firefox.git
export MOZILLA_UNIFIED_REV ?= FIREFOX_147_0_3_RELEASE

PDF_JS := $(CURDIR)/pdf.js
PDF_JS_URL ?= https://codeberg.org/kafva/pdf.js
PDF_JS_REV ?= 5a127574ea0b0b1550324e4f84ceebcd006ae019

# https://firefox-source-docs.mozilla.org/writing-rust-code/update-policy.html
RUST_VERSION = 1.90

# Target settings
ifeq ($(TARGET),macos)
export TARGET_UNAME := darwin
export TARGET_TRIPLE ?= aarch64-apple-darwin
# export LDFLAGS := -L/usr/local/opt/llvm/lib
# export CPPFLAGS := -I/usr/local/opt/llvm/include
export PATH := /usr/local/opt/llvm/bin:${PATH}

else ifeq ($(TARGET),ubuntu)
export TARGET_UNAME := linux
export TARGET_TRIPLE ?= x86_64-linux-gnu

else ifeq ($(TARGET),archlinux)
export TARGET_UNAME := linux
export TARGET_TRIPLE ?= x86_64-linux-gnu
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

# Paths that differ depending on if we build inside our outside a container
ifneq ($(findstring $(TARGET),macos archlinux),)
export CONTAINER_MNT = $(CURDIR)
export CONTAINER_MOZILLA = $(MOZILLA_UNIFIED)
else
export CONTAINER_MNT = /home/builder/firefox
export CONTAINER_MOZILLA = $(CONTAINER_MNT)/mozilla-unified
endif

# Tag for new build
TAG ?= $(shell date '+%Y.%m.%d')

export MOZ_PARALLEL_BUILD ?= $(shell nproc)
# Avoid terminal-notifier call on completion
export MOZ_AUTOMATION = 1
# Need to be explicitly set for ./mach package stage on macOS(?)
export MOZ_SOURCE_REPO = $(CURDIR)/mozilla-unified
export MOZ_SOURCE_CHANGESET = $(MOZILLA_UNIFIED_REV)
export MOZ_BUILD_DATE = $(shell date '+%Y%m%d%H%M%S')
export MH_BRANCH = $(MOZILLA_UNIFIED_REV)

export OUT := $(CURDIR)/out/$(TARGET)

# Container image name, different tags for different distros
IMAGE_NAME := firefox-builder

# Make sure rust toolchain is found
export PATH := $(HOME)/.cargo/bin:$(PATH)

# Extra arguments for clone
export GIT_CLONE_ARGS ?=
