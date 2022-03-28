R_VERSION = 4.1

.PHONY: repo
repo:
	mkdir -p repo/src/contrib
	R_VERSION=$(R_VERSION) \
	  Rscript repo-update.R

.PHONY: clean
clean:
	rm -rf repo
