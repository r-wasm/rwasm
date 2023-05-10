-include ~/.webr-vars.mk

R_VERSION = $(shell cat $(WEBR_ROOT)/R/R-VERSION)
R_VERSION_SHORT = $(shell grep -Eo '[0-9]+\.[0-9]+' $(WEBR_ROOT)/R/R-VERSION)

R_HOST ?= /usr/local

.PHONY: repo
repo:
	mkdir -p repo/src/contrib lib
	R_VERSION=$(R_VERSION_SHORT) \
	R_HOST=$(R_HOST) \
	PATH="$(WEBR_ROOT)/wasm/bin:${PATH}" \
	PKG_CONFIG_PATH="$(WEBR_ROOT)/wasm/lib/pkgconfig" \
	  $(R_HOST)/bin/Rscript repo-update.R

.PHONY: pkg-%
pkg-%:
	make clean-$*
	mkdir -p repo/src/contrib lib
	R_VERSION=$(R_VERSION_SHORT) \
	R_HOST=$(R_HOST) \
	PATH="$(WEBR_ROOT)/wasm/bin:${PATH}" \
	PKG_CONFIG_PATH="$(WEBR_ROOT)/wasm/lib/pkgconfig" \
	  $(R_HOST)/bin/Rscript repo-update.R $*

.PHONY: clean
clean:
	rm -rf repo lib

.PHONY: clean-%
clean-%:
	rm -rf repo/src/contrib/$**
	rm -rf repo/bin/emscripten/contrib/$(R_VERSION_SHORT)/$**
	rm -rf lib/$*
	make PACKAGES

.PHONY: PACKAGES
PACKAGES:
	$(R_HOST)/bin/Rscript -e "tools::write_PACKAGES('repo/src/contrib')"
	$(R_HOST)/bin/Rscript -e "tools::write_PACKAGES('repo/bin/emscripten/contrib/$(R_VERSION_SHORT)', type = 'mac.binary')"


# Print Makefile variable
.PHONY: print-%
print-%  : ; @echo $* = $($*)
