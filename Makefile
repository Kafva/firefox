include config.mk

source: $(MOZILLA_UNIFIED) \
	    $(PDF_JS)

all: source 

# https://firefox-source-docs.mozilla.org/setup/linux_build.html
$(MOZILLA_UNIFIED):
	@echo ">>> Fetching firefox source"
	python3 -m pip install --user mercurial
	curl -LO 'https://hg.mozilla.org/mozilla-central/raw-file/default/python/mozboot/bin/bootstrap.py'
	python3 bootstrap.py --vcs=git --application-choice="Firefox for Desktop"
	rm -f bootstrap.py

$(PDF_JS):
	git clone $(PDF_JS_URL) $@


pdfjs: $(PDF_JS)
	@echo '>>> Building pdf.js'
	(cd pdf.js && \
		$(NPM) install --legacy-peer-deps --ignore-scripts)
	(cd pdf.js && \
		gulp mozcentral)

mozconfigure:
	@# Configure mozilla-unified to use our fork
	$(CURDIR)/scripts/yq \
		-p origin.url \
		-s "$(PDF_JS_URL)" \
		$(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml
	$(CURDIR)/scripts/yq \
		-p origin.release \
		-s "$(shell git -C $(PDF_JS) rev-parse HEAD)" \
		$(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml
	$(CURDIR)/scripts/yq \
		-p origin.revision \
		-s "$(shell git -C $(PDF_JS) rev-parse HEAD)" \
		$(MOZILLA_UNIFIED)/toolkit/components/pdfjs/moz.yaml

distclean:
	rm -rf bootstrap.py $(CURDIR)/mozilla-unified $(CURDIR)/pdf.js
