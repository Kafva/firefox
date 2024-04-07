# URL to fork of pdf.js to use
PDF_JS_URL ?= https://github.com/kafva/pdf.js

MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
PDF_JS          := $(CURDIR)/pdf.js
PDF_JS_MOZ_YAML := $(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml
NPM             := npm

UNAME		    := $(shell uname -s)

ifeq ($(UNAME),Linux)
# Separate output directories for different build targets, allows us to build
# with podman from one host.
OUT             := $(CURDIR)/out/$(shell lsb_release -si)
else
OUT             := $(CURDIR)/out/$(UNAME)
endif

