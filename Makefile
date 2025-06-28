include config.mk

.PHONY: build

all: build

source: $(MOZILLA_UNIFIED) \
	    $(PDF_JS)

define msg
	@printf "\033[3m>>>> $(1)\033[0m\n"
endef

# $1: Distribution name
# $2: Extra docker flags
define docker_run
	docker buildx build \
		--build-arg BUILDER_UID=$(shell id -u) \
		--build-arg BUILDER_GID=$(shell id -g) \
		-f docker/${1}.dockerfile -t $(IMAGE_NAME):${1} $(CURDIR)
	docker run -it -u $(shell id -u):$(shell id -g) --rm \
		${2} \
		--mount type=bind,src=$(CURDIR),dst=/home/builder/firefox,ro=false \
		$(IMAGE_NAME):${1}
endef

### containers #################################################################
ubuntu: docker/ubuntu.dockerfile
	$(call docker_run,ubuntu)

ubuntu-shell: docker/ubuntu.dockerfile
	$(call docker_run,ubuntu,--entrypoint /bin/bash)

archlinux: docker/archlinux.dockerfile
	$(call docker_run,archlinux)

archlinux-shell: docker/archlinux.dockerfile
	$(call docker_run,archlinux,--entrypoint /bin/bash)

### firefox ####################################################################
$(MOZILLA_UNIFIED):
	$(call msg,Fetching firefox source)
	git -c fetch.prune=true \
		-c remote.origin.prune=true \
		clone hg::$(MOZILLA_UNIFIED_URL)
	git -C $(MOZILLA_UNIFIED) config remote.origin.prune true
	git -C $(MOZILLA_UNIFIED) config fetch.prune true
	git -C $(MOZILLA_UNIFIED) cinnabar fetch --tags
	git -C $(MOZILLA_UNIFIED) checkout $(MOZILLA_UNIFIED_REV)
	(cd $(MOZILLA_UNIFIED) && ./mach bootstrap --application-choice="Firefox for Desktop")
ifeq ($(UNAME),darwin)
	@# The `bootstrap` command installs some packages with brew automatically,
	@# the terminal-notifier can make the build hang when running in headless
	@# mode, remove it.
	brew uninstall terminal-notifier 2> /dev/null || :
endif

patch: $(MOZILLA_UNIFIED)/.patched
$(MOZILLA_UNIFIED)/.patched: $(MOZILLA_UNIFIED) $(PDF_JS)/build/mozcentral
	$(call msg,Configuring mozilla-unified)
	@# Configure git
	git -C $(MOZILLA_UNIFIED) config --local commit.gpgsign false
	@# Update moz.yaml to point to our pdf.js fork
	git -C $(MOZILLA_UNIFIED) reset --hard $(MOZILLA_UNIFIED_REV)
	@# Cleanup from previous failures
	-git -C $(MOZILLA_UNIFIED) am --abort 2> /dev/null
	@# Apply mozilla-unified patches
	for patch in $(CURDIR)/patches/*.patch; do \
		git -C $(MOZILLA_UNIFIED) am --3way $$patch; \
	done
	@# Run the part of mozilla-unified/toolkit/components/pdfjs/update.sh
	@# which copies output from:
	@#   $(PDF_JS)/build/mozcentral
	@# into
	@#   $(MOZILLA_UNIFIED)/toolkit/components/pdfjs
	$(call msg,Configuring mozilla-unified/toolkit/components/pdf.js)
	cp $(PDF_JS)/LICENSE $(MOZILLA_UNIFIED)/toolkit/components/pdfjs/
	cp $(PDF_JS)/build/mozcentral/browser/extensions/pdfjs/PdfJsDefaultPrefs.js \
		$(MOZILLA_UNIFIED)/toolkit/components/pdfjs/PdfJsDefaultPrefs.js
	rsync -a -v --delete $(PDF_JS)/build/mozcentral/browser/extensions/pdfjs/content/build/ \
		$(MOZILLA_UNIFIED)/toolkit/components/pdfjs/content/build/
	rsync -a -v --delete $(PDF_JS)/build/mozcentral/browser/extensions/pdfjs/content/web/ \
		$(MOZILLA_UNIFIED)/toolkit/components/pdfjs/content/web/
	-cp $(PDF_JS)/build/mozcentral/browser/locales/en-US/pdfviewer/*.ftl \
		$(MOZILLA_UNIFIED)/toolkit/locales/en-US/toolkit/pdfviewer/
	@# Update the revision in the toolchains.yml file for the Talos tests.
	sed -i -z "s/\(mozilla-pdf\.js.*revision: \)[0-9a-f]*/\1$1/g" \
		$(MOZILLA_UNIFIED)/taskcluster/kinds/fetch/toolchains.yml
	git -C $(MOZILLA_UNIFIED) add toolkit/components/pdfjs
	touch $@

build: $(MOZILLA_UNIFIED)/.patched
	@# Add our mozconfig
	cp $(CURDIR)/conf/mozconfig $(MOZILLA_UNIFIED)/mozconfig
	cat $(CURDIR)/conf/mozconfig_$(UNAME) >> $(MOZILLA_UNIFIED)/mozconfig
	mkdir -p $(OUT)
	(cd $(MOZILLA_UNIFIED) && ./mach build)
ifeq ($(UNAME),linux)
	(cd $(MOZILLA_UNIFIED) && DESTDIR="$(OUT)/firefox-nightly" ./mach install)
	tar -C $(OUT)/firefox-nightly -cf - . | \
		pzstd -f - -o $(OUT)/firefox-nightly-$(DISTRO).tar.zst
	@echo "sudo cp -r $(OUT)/firefox-nightly/usr/* /usr"
else ifeq ($(UNAME),darwin)
	@# Create installer .dmg
	(cd $(MOZILLA_UNIFIED) && ./mach package)
	cp -v $(MOZILLA_UNIFIED)/obj-aarch64-apple-darwin/dist/firefox-*.en-US.mac.dmg $(OUT)
endif
	$(call msg,Done)

### pdf.js #####################################################################
pdfjs: $(PDF_JS)/build/mozcentral

$(PDF_JS):
	git clone $(PDF_JS_URL) $@

$(PDF_JS)/build/mozcentral: $(PDF_JS)
	$(call msg,Building pdf.js)
	cd $(PDF_JS) && npm install --legacy-peer-deps --ignore-scripts
	cd $(PDF_JS) && npx gulp mozcentral


################################################################################

unpatch:
	rm -f $(MOZILLA_UNIFIED)/.patched

clean: unpatch
	-cd $(MOZILLA_UNIFIED) 2> /dev/null && ./mach clobber
	-cd $(PDF_JS) 2> /dev/null && rm -rf build

distclean:
	rm -rf bootstrap.py $(MOZILLA_UNIFIED) $(PDF_JS)
