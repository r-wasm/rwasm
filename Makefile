-include ~/.webr-vars.mk

R_VERSION = 4.1
R_HOST ?= /usr/local

.PHONY: repo
repo:
	mkdir -p repo/src/contrib lib
	R_VERSION=$(R_VERSION) \
	  $(R_HOST)/bin/Rscript repo-update.R

.PHONY: pkg-%
pkg-%:
	make clean-$*
	mkdir -p repo/src/contrib lib
	R_VERSION=$(R_VERSION) \
	  $(R_HOST)/bin/Rscript repo-update.R $*

.PHONY: clean
clean:
	rm -rf repo lib

.PHONY: clean-%
clean-%:
	rm -rf repo/src/contrib/$**
	rm -rf repo/bin/emscripten/contrib/$(R_VERSION)/$**
	rm -rf lib/$*
	make PACKAGES

.PHONY: PACKAGES
PACKAGES:
	$(R_HOST)/bin/Rscript -e "tools::write_PACKAGES('repo/src/contrib', verbose = TRUE)"
	$(R_HOST)/bin/Rscript -e "tools::write_PACKAGES('repo/bin/emscripten/contrib/$(R_VERSION)', type = 'mac.binary', verbose = TRUE)"
