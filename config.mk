# URL to fork of pdf.js to use
PDF_JS_URL ?= https://github.com/kafva/pdf.js
# URL to clone mozilla-unified from
MOZILLA_UNIFIED_URL ?= https://hg.mozilla.org/mozilla-unified
# Branch of mozilla-unified to use
MOZILLA_UNIFIED_BRANCH ?= bookmarks/release

MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
PDF_JS          := $(CURDIR)/pdf.js
PDF_JS_MOZ_YAML := $(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml
# Name of builder image, different tags for different distros.
IMAGE_NAME      := firefox-builder

UNAME		    := $(shell uname -s)

ifeq ($(UNAME),Linux)
# Separate output directories for different build targets, allows us to build
# with podman from one host.
OUT             := $(CURDIR)/out/$(shell lsb_release -si)
else
OUT             := $(CURDIR)/out/$(UNAME)
endif

# mozilla-unified build options
export MOZ_PARALLEL_BUILD ?= $(shell nproc)
export MOZ_OBJDIR ?= $(MOZILLA_UNIFIED)/obj
export RUSTC ?= ~/.cargo/bin/rustc
export CARGO ?= ~/.cargo/bin/cargo


