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
	MOZILLA_UNIFIED_REV ?= FIREFOX_NIGHTLY_125_END

	# Separate output directories for different build targets, allows us to build
	# with podman from one host.
	OUT := $(CURDIR)/out/$(shell lsb_release -si | tr '[:upper:]' '[:lower:]')
	export MOZ_PARALLEL_BUILD ?= $(shell nproc)

else ifeq ($(UNAME),darwin)
	MOZILLA_UNIFIED_REV ?= FIREFOX_NIGHTLY_120_END

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
