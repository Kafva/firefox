# URL to fork of pdf.js to use
PDF_JS_URL ?= https://github.com/kafva/pdf.js

MOZILLA_UNIFIED := $(CURDIR)/mozilla-unified
PDF_JS          := $(CURDIR)/pdf.js
PDF_JS_MOZ_YAML := $(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml
NPM             := npm
OUT             := $(CURDIR)/out


UNAME		    := $(shell uname -s)



