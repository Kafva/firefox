include config.mk

.PHONY: build

all: build

source: $(MOZILLA_UNIFIED)/.cloned \
	    $(PDF_JS)/.cloned

define msg
	@printf "\033[3m>>>> $(1)\033[0m\n"
endef

# $1: Distribution name
# $2: Extra docker flags
# Note: Variables passed from CLI need to explicitly passed here
define docker_run
	docker buildx build \
		--build-arg BUILDER_UID=$(shell id -u) \
		--build-arg BUILDER_GID=$(shell id -g) \
		-f docker/${1}.dockerfile -t $(IMAGE_NAME):${1} $(CURDIR)
	docker run -it -u $(shell id -u):$(shell id -g) --rm \
		-e MOZILLA_UNIFIED_REV=$(MOZILLA_UNIFIED_REV) \
		-e TARGET=$(TARGET) \
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

build: $(MOZILLA_UNIFIED)/.patched
	@# Add our mozconfig
	cp $(CURDIR)/conf/mozconfig $(MOZILLA_UNIFIED)/mozconfig
	cat $(CURDIR)/conf/mozconfig_$(UNAME) >> $(MOZILLA_UNIFIED)/mozconfig
	echo "ac_add_options --target=$(TARGET)" >> $(MOZILLA_UNIFIED)/mozconfig
	mkdir -p $(OUT)
	(cd $(MOZILLA_UNIFIED) && ./mach -l build.log build)
ifeq ($(UNAME),linux)
	(cd $(MOZILLA_UNIFIED) && DESTDIR="$(OUT)/firefox-nightly" ./mach install)
	tar -C $(OUT)/firefox-nightly -cf - . | \
		pzstd -f - -o $(OUT)/$(MOZILLA_UNIFIED_REV)-$(DISTRO)-$(TARGET).tar.zst
	@echo "sudo cp -r $(OUT)/firefox-nightly/usr/* /usr"
else ifeq ($(UNAME),darwin)
	@# Create installer .dmg
	(cd $(MOZILLA_UNIFIED) && ./mach package)
	cp -v $(MOZILLA_UNIFIED)/obj-aarch64-apple-darwin/dist/firefox-*-$(TARGET).en-US.mac.dmg $(OUT)
endif
	$(call msg,Done)

### pdf.js #####################################################################
pdfjs: $(PDF_JS)/build/mozcentral

$(PDF_JS)/.cloned:
	git clone $(GIT_CLONE_ARGS) $(PDF_JS_URL) $(@D)
	touch $@

$(PDF_JS)/build/mozcentral: $(PDF_JS)/.cloned
	$(call msg,Building pdf.js)
	git -C $(PDF_JS) checkout $(PDF_JS_REV)
	cd $(PDF_JS) && npm install --legacy-peer-deps --ignore-scripts
	cd $(PDF_JS) && npx gulp mozcentral


################################################################################

unpatch:
	rm -f $(MOZILLA_UNIFIED)/.patched

clean: unpatch
	-cd $(MOZILLA_UNIFIED) 2> /dev/null && ./mach clobber
	-cd $(PDF_JS) 2> /dev/null && rm -rf build

release:
	git tag -f $(TAG)
	-git push -d origin $(TAG) 2> /dev/null
	git push origin $(TAG)
	gh release create $(TAG) $(wildcard out/darwin/*.dmg)
	gh release upload $(TAG) $(wildcard out/*/*.tar.zst)

distclean:
	rm -rf $(MOZILLA_UNIFIED) $(PDF_JS)
