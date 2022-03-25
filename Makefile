R_VERSION = 4.1
PACKAGES = brio rlang

.PHONY: repo
repo:
	mkdir -p repo/src/contrib
	R_VERSION=$(R_VERSION) \
	  Rscript repo-update.R $(PACKAGES)

.PHONY: clean
clean:
	rm -rf repo
