R_VERSION = 4.1
PACKAGES = R6 cli brio desc glue rlang rprojroot

.PHONY: repo
repo:
	mkdir -p repo/src/contrib
	R_VERSION=$(R_VERSION) \
	  Rscript repo-update.R $(PACKAGES)

.PHONY: clean
clean:
	rm -rf repo
