MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
MOZILLA_UNIFIED_URL := https://github.com/mozilla-firefox/firefox.git

PDF_JS := $(CURDIR)/pdf.js
PDF_JS_URL ?= https://github.com/kafva/pdf.js
PDF_JS_REV ?= 2538a9b889152c278cc519edb40abc35e59000f6

# Tag for new build
TAG ?= $(shell date '+%Y.%m.%d')

UNAME := $(shell uname -s | tr '[:upper:]' '[:lower:]')

ifeq ($(UNAME),linux)
# Branch/tag of mozilla-unified to use
export MOZILLA_UNIFIED_REV ?= FIREFOX_NIGHTLY_143_END
export TARGET ?= x86_64-linux-gnu

# Separate output directories for different build targets, allows us to build
# with docker from one host.
DISTRO := $(shell sed -n 's/^ID=\(.*\)/\1/p' /etc/os-release 2> /dev/null)
OUT := $(CURDIR)/out/$(DISTRO)
export MOZ_PARALLEL_BUILD ?= $(shell nproc)

else ifeq ($(UNAME),darwin)
export MOZILLA_UNIFIED_REV ?= FIREFOX_NIGHTLY_143_END
export TARGET ?= aarch64-apple-darwin

OUT := $(CURDIR)/out/$(UNAME)
export MOZ_PARALLEL_BUILD ?= $(shell sysctl -n hw.logicalcpu)
export LDFLAGS := -L/usr/local/opt/llvm/lib
export CPPFLAGS := -I/usr/local/opt/llvm/include
export PATH := /usr/local/opt/llvm/bin:${PATH}

else
$(error Unsupported platform $(UNAME))
endif

# Docker image name, differentt tags for different distros
IMAGE_NAME      := firefox-builder

# Make sure rust toolchain is found
export PATH := ${HOME}/.cargo/bin:${PATH}

# Extra arguments for clone
GIT_CLONE_ARGS ?=
