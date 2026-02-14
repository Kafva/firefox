include config.mk

define msg
	@printf "\033[3m>>>> $(1)\033[0m\n"
endef

# $1: Current working directory in container
# $2: Command line to execute
define container_run
	@if [ -z "$(DIST)" ]; then \
		echo "No DIST set"; \
		exit 1; \
	elif [ "$(DIST)" = macos ]; then \
		cd ${1} && ${2}; \
	else \
		$(CONTAINER_BUILD) \
			--build-arg BUILDER_UID=$(shell id -u) \
			--build-arg BUILDER_GID=$(shell id -g) \
			-f docker/$(DIST).dockerfile -t $(IMAGE_NAME):$(DIST) $(CURDIR); \
		$(CONTAINER_RUN) -it -u $(shell id -u):$(shell id -g) --rm \
			-e DIST=$(DIST) \
			-e TARGET=$(TARGET) \
			--mount type=bind,src=$(CURDIR),dst=$(CONTAINER_MNT),ro=false \
			-w ${1} \
			$(IMAGE_NAME):$(DIST) /bin/bash -c "${2}"; \
	fi
endef

## targets #####################################################################

source: $(MOZILLA_UNIFIED)/.cloned $(PDF_JS)/.cloned

shell: $(wildcard docker/*.dockerfile)
	$(call container_run,$(CONTAINER_MNT),bash)

build:
	$(call container_run,$(CONTAINER_MNT),$(MAKE) _build 2>&1 | \
		tee ./mozilla-unified/build-$(shell date '+%Y-%m-%d-%H-%M').log)

all:
ifeq ($(shell uname),Darwin)
	$(MAKE) DIST=macos clean
	$(MAKE) DIST=macos build
endif
	$(MAKE) DIST=ubuntu clean
	$(MAKE) DIST=ubuntu build

	$(MAKE) DIST=archlinux clean
	$(MAKE) DIST=archlinux build

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
	gh release upload $(TAG) $(wildcard out/*/*.tar.zst)

unpatch:
	rm -f $(MOZILLA_UNIFIED)/.patched

clean: unpatch
	-cd $(PDF_JS) 2> /dev/null && rm -rf build
	$(call container_run,$(CONTAINER_MOZILLA),./mach clobber)

distclean:
	rm -rf $(MOZILLA_UNIFIED) $(PDF_JS)

## mach ########################################################################

# Do not invoke mach manually, the build system will try to rebuild way too much
# due to environment differences.
#
# Possible arguments for ac_add_options
# 	./configure --help

mach-ccdb:
	$(call container_run,$(CONTAINER_MOZILLA),\
		./mach build-backend --backend=CompileDB)

mach-build:
	$(call container_run,$(CONTAINER_MOZILLA),\
		./mach build && \
		DESTDIR="$(CONTAINER_MNT)/out/$(DIST)/firefox-nightly" ./mach install)

mach-run:
	@# No container wrapper when launching firefox
	@mkdir -p $(MOZILLA_UNIFIED)/.my_profile
	cd $(MOZILLA_UNIFIED) && ./mach run -n -- --profile ./.my_profile

### firefox ####################################################################
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
	$(call msg,Building target $(DIST) $(TARGET_UNAME) $(TARGET))
	@# Set rust toolchain version
	rustup default $(RUST_VERSION)
	@# Add our mozconfig
	cp $(CURDIR)/conf/mozconfig $(MOZILLA_UNIFIED)/mozconfig
	cat $(CURDIR)/conf/mozconfig_$(TARGET_UNAME) >> $(MOZILLA_UNIFIED)/mozconfig
	echo "ac_add_options --target=$(TARGET)" >> $(MOZILLA_UNIFIED)/mozconfig
	mkdir -p $(OUT)
	cd $(MOZILLA_UNIFIED) && ./mach build
ifeq ($(TARGET_UNAME),linux)
	cd $(MOZILLA_UNIFIED) && DESTDIR="$(OUT)/firefox-nightly" ./mach install
	tar -C $(OUT)/firefox-nightly -cf - . | \
		pzstd -f - -o $(OUT)/$(MOZILLA_UNIFIED_REV)-$(DIST)-$(TARGET).tar.zst
	@echo "sudo cp -r $(OUT)/firefox-nightly/usr/* /usr"
else ifeq ($(TARGET_UNAME),darwin)
	@# Create installer .dmg
	cd $(MOZILLA_UNIFIED) && ./mach package
	cp $(MOZILLA_UNIFIED)/obj-aarch64-apple-darwin/dist/firefox-*.en-US.mac.dmg $(OUT)
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
