include config.mk

.PHONY: build

all: build

source: $(MOZILLA_UNIFIED) \
	    $(PDF_JS)

define msg
	@printf "\033[3m>>>> $(1)\033[0m\n"
endef

# $1: Distribution name
# $2: Extra podman flags
define podman_run
	podman build \
		--build-arg BUILDER_UID=$(shell id -u) \
		--build-arg BUILDER_GID=$(shell id -g) \
		-f docker/${1}.dockerfile -t $(IMAGE_NAME):${1} $(CURDIR)
	podman run --userns keep-id --rm \
		${2} \
		--mount type=bind,src=$(CURDIR),dst=/home/builder/firefox,ro=false \
		$(IMAGE_NAME):${1}
endef

### containers #################################################################
ubuntu: docker/ubuntu.dockerfile
	$(call podman_run,ubuntu)

ubuntu-shell: docker/ubuntu.dockerfile
	$(call podman_run,ubuntu,-it --entrypoint /bin/bash)

archlinux: docker/archlinux.dockerfile
	$(call podman_run,archlinux)

archlinux-shell: docker/archlinux.dockerfile
	$(call podman_run,archlinux,-it --entrypoint /bin/bash)

### firefox ####################################################################
$(MOZILLA_UNIFIED):
	$(call msg,Fetching firefox source)
	git -c fetch.prune=true \
		-c remote.origin.prune=true \
		clone hg::$(MOZILLA_UNIFIED_URL)
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
	$(call,Configuring pdf.js for mozilla-unified)
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
	cd $(MOZILLA_UNIFIED)/toolkit/components/pdfjs && \
		PDFJS_CHECKOUT=$(PDF_JS) GECKO_PATH=$(MOZILLA_UNIFIED) \
			./update.sh "$(shell git -C $(PDF_JS) rev-parse HEAD)"
	$(call msg,update.sh done)
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
		pzstd -f --ultra -22 - -o $(OUT)/firefox-nightly.tar.zst
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
	cd pdf.js && \
		npm install --legacy-peer-deps --ignore-scripts
	cd pdf.js && \
		gulp mozcentral


################################################################################

unpatch:
	rm -f $(MOZILLA_UNIFIED)/.patched

clean: unpatch
	-cd $(MOZILLA_UNIFIED) 2> /dev/null && ./mach clobber
	-cd $(PDF_JS) 2> /dev/null && rm -rf build

distclean:
	rm -rf bootstrap.py $(MOZILLA_UNIFIED) $(PDF_JS)
