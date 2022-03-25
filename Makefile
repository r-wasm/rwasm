R_VERSION = 4.1
PACKAGES = brio rlang

repo:
	mkdir -p repo/src/contrib
	R_VERSION=$(R_VERSION) \
	  Rscript repo-create.R $(PACKAGES)

.PHONY: update
update: repo
	R_VERSION=$(R_VERSION) \
	  Rscript repo-update.R

.PHONY: clean
clean:
	rm -rf repo
