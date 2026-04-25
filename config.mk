MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
MOZILLA_UNIFIED_URL := https://github.com/mozilla-firefox/firefox.git
export MOZILLA_UNIFIED_REV ?= FIREFOX_150_0_BUILD1

PDF_JS := $(CURDIR)/pdf.js
PDF_JS_URL ?= https://codeberg.org/kafva/pdf.js
PDF_JS_REV ?= c97b89f37f15df8a5d61d38e3b7064d40d5a4276

# https://firefox-source-docs.mozilla.org/writing-rust-code/update-policy.html
RUST_VERSION = 1.94

# Target settings
ifeq ($(TARGET),macos)
export TARGET_TRIPLE ?= aarch64-apple-darwin
# export LDFLAGS := -L/usr/local/opt/llvm/lib
# export CPPFLAGS := -I/usr/local/opt/llvm/include
export PATH := /usr/local/opt/llvm/bin:${PATH}

else ifeq ($(TARGET),linux)
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
ifeq ($(TARGET),macos)
export CONTAINER_MNT = $(CURDIR)
export CONTAINER_MOZILLA = $(MOZILLA_UNIFIED)
else
export CONTAINER_MNT = /home/builder/firefox
export CONTAINER_MOZILLA = $(CONTAINER_MNT)/mozilla-unified
endif

# Tag for new build
TAG ?= $(shell date '+%Y.%m.%d')

export OUT := $(CURDIR)/out/$(TARGET)

# Disable terminal-notifier and hide warnings from the build log.
# Do not use MOZ_AUTOMATION, it has *many* other side-effects besides disabling
# the terminal-notifier, we want a manually invoked ./mach to be as similar to
# the ./mach we run here as possible.
export MOZ_NOSPAM = true

export MOZ_PARALLEL_BUILD ?= $(shell nproc)
# Need to be explicitly set for ./mach package stage on macOS(?)
export MOZ_SOURCE_REPO = $(CURDIR)/mozilla-unified
export MOZ_SOURCE_CHANGESET = $(MOZILLA_UNIFIED_REV)
export MOZ_BUILD_DATE = $(shell date '+%Y%m%d%H%M%S')
export MH_BRANCH = $(MOZILLA_UNIFIED_REV)
