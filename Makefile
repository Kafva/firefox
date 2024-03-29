include config.mk

source: $(CURDIR)/mozilla-unified \
	    $(CURDIR)/pdf.js

# https://firefox-source-docs.mozilla.org/setup/linux_build.html
$(CURDIR)/mozilla-unified:
	python3 -m pip install --user mercurial
	curl -LO 'https://hg.mozilla.org/mozilla-central/raw-file/default/python/mozboot/bin/bootstrap.py'
	python3 bootstrap.py --vcs=git --application-choice="Firefox for Desktop"
	rm -f bootstrap.py

$(CURDIR)/pdf.js:
	git clone $(PDF_JS) $@

distclean:
	rm -rf bootstrap.py $(CURDIR)/mozilla-unified $(CURDIR)/pdf.js
