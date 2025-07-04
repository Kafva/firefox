# URL to fork of pdf.js to use
PDF_JS_URL ?= https://github.com/kafva/pdf.js
# URL to clone mozilla-unified from
MOZILLA_UNIFIED_URL ?= https://hg.mozilla.org/mozilla-unified

MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
PDF_JS          := $(CURDIR)/pdf.js
PDF_JS_MOZ_YAML := $(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml
# Name of builder image, different tags for different distros.
IMAGE_NAME      := firefox-builder

UNAME := $(shell uname -s | tr '[:upper:]' '[:lower:]')

ifeq ($(UNAME),linux)
# Branch/tag of mozilla-unified to use
export MOZILLA_UNIFIED_REV ?= FIREFOX_NIGHTLY_139_END
export TARGET ?= x86_64-linux-gnu

# Separate output directories for different build targets, allows us to build
# with docker from one host.
DISTRO := $(shell sed -n 's/^ID=\(.*\)/\1/p' /etc/os-release 2> /dev/null)
OUT := $(CURDIR)/out/$(DISTRO)
export MOZ_PARALLEL_BUILD ?= $(shell nproc)

else ifeq ($(UNAME),darwin)
export MOZILLA_UNIFIED_REV ?= FIREFOX_NIGHTLY_139_END
export TARGET ?= aarch64-apple-darwin

OUT := $(CURDIR)/out/$(UNAME)
export MOZ_PARALLEL_BUILD ?= $(shell sysctl -n hw.logicalcpu)
export LDFLAGS := -L/usr/local/opt/llvm/lib
export CPPFLAGS := -I/usr/local/opt/llvm/include
export PATH := /usr/local/opt/llvm/bin:${PATH}

else
$(error Unsupported platform $(UNAME))
endif

# Make sure rust toolchain is found
export PATH := ${HOME}/.cargo/bin:${PATH}
