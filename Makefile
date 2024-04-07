include config.mk

all: build 

source: $(MOZILLA_UNIFIED) \
	    $(PDF_JS)

#== firefox ===================================================================#
$(MOZILLA_UNIFIED):
	@echo ">>> Fetching firefox source"
	@echo ">>> NOTE: bootstrap.py will prompt for interactive input"
	python3 -m pip install --user mercurial
	curl -LO 'https://hg.mozilla.org/mozilla-central/raw-file/default/python/mozboot/bin/bootstrap.py'
	python3 bootstrap.py --vcs=git --application-choice="Firefox for Desktop"
	rm -f bootstrap.py
	(cd $(MOZILLA_UNIFIED) && ./mach bootstrap --application-choice="Firefox for Desktop")

configure: $(MOZILLA_UNIFIED)
	@echo ">>> Configuring mozilla-unified"
	@# Update moz.yaml to point to our pdf.js fork
	git -C $(MOZILLA_UNIFIED) reset --hard origin/bookmarks/central
	git -C $(MOZILLA_UNIFIED) config --local commit.gpgsign false
	@# Cleanup from previous failures
	git -C $(MOZILLA_UNIFIED) am --abort || :
	@# Apply mozilla-unified patches
	for patch in $(CURDIR)/patches/*.patch; do \
		git -C $(MOZILLA_UNIFIED) am $$patch; \
	done

configure-pdfjs: $(PDF_JS)
	@echo ">>> Configuring pdf.js for mozilla-unified"
	$(CURDIR)/scripts/yq \
		-p origin.url \
		-s "$(PDF_JS_URL)" \
		$(PDF_JS_MOZ_YAML)
	$(CURDIR)/scripts/yq \
		-p origin.release \
		-s "$(shell git -C $(PDF_JS) rev-parse HEAD)" \
		$(PDF_JS_MOZ_YAML)
	$(CURDIR)/scripts/yq \
		-p origin.revision \
		-s "$(shell git -C $(PDF_JS) rev-parse HEAD)" \
		$(PDF_JS_MOZ_YAML)
	@# Commit the changes
	git -C $(MOZILLA_UNIFIED) add $(PDF_JS_MOZ_YAML)
	git -C $(MOZILLA_UNIFIED) commit -m "[AUTOMATED] update pdf.js version"
	@# Update the checkout of pdfjs that is used
	@# This will detach the $(PDF_JS) checkout so that it points to the HEAD commit
	(cd $(MOZILLA_UNIFIED) && \
		PDFJS_CHECKOUT=$(PDF_JS) ./mach vendor $(PDF_JS_MOZ_YAML))
	@# Build and sync the mozcentral target from the custom pdf.js with mozilla-unified
	@# The update.sh script copies files from
	@#   $(PDF_JS)/build/mozcentral
	@# into
	@#   $(MOZILLA_UNIFIED)/toolkit/components/pdfjs
	@#
	@# !! `update.sh` uses [ -v ] which is not valid for the built-in bash on macOS !!
	cd $(MOZILLA_UNIFIED)/toolkit/components/pdfjs && \
		PDFJS_CHECKOUT=$(PDF_JS) GECKO_PATH=$(MOZILLA_UNIFIED) \
			./update.sh "$(shell git -C $(PDF_JS) rev-parse HEAD)"
	@echo ">>> update.sh done"

build: configure configure-pdfjs
	@# Add our mozconfig
ifeq ($(UNAME),Darwin)
	cp $(CURDIR)/conf/mozconfig_darwin $(MOZILLA_UNIFIED)/mozconfig
else
	cp $(CURDIR)/conf/mozconfig_linux $(MOZILLA_UNIFIED)/mozconfig
endif
	(cd $(MOZILLA_UNIFIED) && ./mach build)
	(cd $(MOZILLA_UNIFIED) && DESTDIR="$(OUT)/firefox-nightly" ./mach install)
	@echo ">>> Done"
	@echo "sudo cp -r $(OUT)/firefox-nightly/usr /usr"

#== pdf.js ====================================================================#
$(PDF_JS):
	git clone $(PDF_JS_URL) $@


pdfjs: $(PDF_JS)
	@echo '>>> Building pdf.js'
	(cd pdf.js && \
		$(NPM) install --legacy-peer-deps --ignore-scripts)
	(cd pdf.js && \
		gulp mozcentral)


#==============================================================================#

clean:
	(cd $(MOZILLA_UNIFIED) && ./mach clobber)
	(cd $(PDF_JS) && rm -rf build)

distclean:
	rm -rf bootstrap.py $(CURDIR)/mozilla-unified $(CURDIR)/pdf.js
