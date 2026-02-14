include config.mk

.PHONY: build all source shell release unpatch patch

define msg
	@printf "\033[3m>>>> $(1)\033[0m\n"
endef

# $1: Cwd to use
# $2: Command line to execute
define run
	@if [ -z "$(TARGET)" ]; then \
		echo "No TARGET set"; \
		exit 1; \
	elif [ "$(TARGET)" = macos ] || [ "$(TARGET)" = archlinux ]; then \
		cd ${1} && ${2}; \
	else \
		$(CONTAINER_BUILD) \
			--build-arg BUILDER_UID=$(shell id -u) \
			--build-arg BUILDER_GID=$(shell id -g) \
			-f docker/$(TARGET).dockerfile -t $(IMAGE_NAME):$(TARGET) $(CURDIR); \
		$(CONTAINER_RUN) -it -u $(shell id -u):$(shell id -g) --rm \
			-e TARGET=$(TARGET) \
			-e TARGET_TRIPLE=$(TARGET_TRIPLE) \
			--mount type=bind,src=$(CURDIR),dst=$(CONTAINER_MNT),ro=false \
			-w ${1} \
			$(IMAGE_NAME):$(TARGET) /bin/bash -c "${2}"; \
	fi
endef

source: $(MOZILLA_UNIFIED)/.cloned $(PDF_JS)/.cloned

shell: $(wildcard docker/*.dockerfile)
	$(call run,$(CONTAINER_MNT),bash)

build:
	$(call run,$(CONTAINER_MNT),$(MAKE) _build 2>&1 | \
		tee ./mozilla-unified/build-$(shell date '+%Y-%m-%d-%H-%M').log)

all:
ifeq ($(shell uname),Darwin)
	$(MAKE) TARGET=macos clean
	$(MAKE) TARGET=macos build
endif
	$(MAKE) TARGET=ubuntu clean
	$(MAKE) TARGET=ubuntu build

	$(MAKE) TARGET=archlinux clean
	$(MAKE) TARGET=archlinux build

release:
	git tag -f $(TAG)
	git remote add gh git@github.com:Kafva/firefox.git 2> /dev/null || :
	git push -d gh $(TAG) 2> /dev/null || :
	git push gh $(TAG)
	git push -d origin $(TAG) 2> /dev/null || :
	git push origin $(TAG)
	@# Make sure release has been created server side
	sleep 10
	gh release create --notes-from-tag --title $(TAG) $(TAG) $(wildcard out/macos/*.dmg)
	gh release upload $(TAG) $(wildcard out/*/*.tar.xz)

unpatch:
	rm -f $(MOZILLA_UNIFIED)/.patched

env:
	@env

clean: unpatch
	-cd $(PDF_JS) 2> /dev/null && rm -rf build
	$(call run,$(CONTAINER_MOZILLA),./mach clobber)

distclean:
	rm -rf $(MOZILLA_UNIFIED) $(PDF_JS)

### Firefox ####################################################################
$(MOZILLA_UNIFIED)/.cloned:
	$(call msg,Fetching firefox source)
	git clone $(GIT_CLONE_ARGS) $(MOZILLA_UNIFIED_URL) $(@D)
	touch $@

patch: $(MOZILLA_UNIFIED)/.patched
$(MOZILLA_UNIFIED)/.patched: $(MOZILLA_UNIFIED)/.cloned $(PDF_JS)/build/mozcentral
	$(call msg,Configuring mozilla-unified)
	@# Reset to choosen revision and cleanup from previous failures
	git -C $(@D) fetch --tags
	git -C $(@D) reset --hard $(MOZILLA_UNIFIED_REV)
	-git -C $(@D) am --abort 2> /dev/null
	@# Apply patches
	$(foreach patch,$(wildcard $(CURDIR)/patches/*.patch),git -C $(@D) am --3way $(patch);)
	@# Run the part of mozilla-unified/toolkit/components/pdfjs/update.sh
	@# which copies output from:
	@#   $(PDF_JS)/build/mozcentral
	@# into
	@#   $(MOZILLA_UNIFIED)/toolkit/components/pdfjs
	$(call msg,Configuring mozilla-unified/toolkit/components/pdf.js)
	cp $(PDF_JS)/LICENSE $(@D)/toolkit/components/pdfjs/
	cp $(PDF_JS)/build/mozcentral/browser/extensions/pdfjs/PdfJsDefaultPrefs.js \
		$(@D)/toolkit/components/pdfjs/PdfJsDefaultPrefs.js
	rsync -a -v --delete $(PDF_JS)/build/mozcentral/browser/extensions/pdfjs/content/build/ \
		$(@D)/toolkit/components/pdfjs/content/build/
	rsync -a -v --delete $(PDF_JS)/build/mozcentral/browser/extensions/pdfjs/content/web/ \
		$(@D)/toolkit/components/pdfjs/content/web/
	-cp $(PDF_JS)/build/mozcentral/browser/locales/en-US/pdfviewer/*.ftl \
		$(@D)/toolkit/locales/en-US/toolkit/pdfviewer/
	@# Update the revision in the toolchains.yml file for the Talos tests.
	sed -i -z "s/\(mozilla-pdf\.js.*revision: \)[0-9a-f]*/\1$1/g" \
		$(@D)/taskcluster/kinds/fetch/toolchains.yml
	git -C $(@D) add toolkit/components/pdfjs
	touch $@

_build: $(MOZILLA_UNIFIED)/.patched
	$(call msg,Building target $(TARGET) $(TARGET_UNAME) $(TARGET_TRIPLE))
	@# Set rust toolchain version
	rustup default $(RUST_VERSION)
	@# Add our mozconfig
	cp $(CURDIR)/conf/mozconfig $(MOZILLA_UNIFIED)/mozconfig
	cat $(CURDIR)/conf/mozconfig_$(TARGET_UNAME) >> $(MOZILLA_UNIFIED)/mozconfig
	echo "ac_add_options --target=$(TARGET_TRIPLE)" >> $(MOZILLA_UNIFIED)/mozconfig
	cd $(MOZILLA_UNIFIED) && ./mach build
	cd $(MOZILLA_UNIFIED) && ./mach package
	mkdir -p $(OUT)
ifeq ($(TARGET_UNAME),linux)
	cp $(MOZILLA_UNIFIED)/obj-*-linux-*/dist/firefox-*.linux-*.tar.xz \
	   $(OUT)/$(MOZILLA_UNIFIED_REV)-$(TARGET)-$(TARGET_TRIPLE).tar.xz
else ifeq ($(TARGET_UNAME),darwin)
	cp $(MOZILLA_UNIFIED)/obj-aarch64-apple-darwin/dist/firefox-*.en-US.mac.dmg $(OUT)/
endif
	@# Restore default toolchain
	rustup default stable
	$(call msg,Done)

### pdf.js #####################################################################
$(PDF_JS)/.cloned:
	git clone $(GIT_CLONE_ARGS) $(PDF_JS_URL) $(@D)
	touch $@

$(PDF_JS)/build/mozcentral: $(PDF_JS)/.cloned
	$(call msg,Building pdf.js)
	git -C $(PDF_JS) checkout $(PDF_JS_REV)
	cd $(PDF_JS) && npm install --legacy-peer-deps --ignore-scripts
	cd $(PDF_JS) && npx gulp mozcentral
