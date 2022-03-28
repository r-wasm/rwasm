packages <- unique(readLines("packages-list"))
writeLines(sprintf("Processing %d packages.", length(packages)))

if (file.exists("repo/src/contrib/PACKAGES")) {
  # Check available packages in the binary folder rather than the
  # source folder so that we retry building failed packages until they
  # succeed
  repo_info <- available.packages("file:repo/bin/emscripten/contrib/4.1")
  repo_packages <- rownames(repo_info)
} else {
  repo_info <- NULL
}

cran_info <- available.packages()
cran_url <- getOption("repos")[["CRAN"]]

r_version <- Sys.getenv("R_VERSION")
webr_contrib_src <- file.path("repo", "src", "contrib")
webr_contrib_bin <- file.path("repo", "bin", "emscripten", "contrib", r_version)

stopifnot(
  rlang::is_string(cran_url),
  dir.exists(webr_contrib_src),
  nzchar(r_version)
)

tarball <- function(pkg, ver) {
  paste0(pkg, "_", ver,  ".tar.gz")
}

need_update <- FALSE

for (pkg in packages) {
  new_ver <- as.package_version(cran_info[pkg, "Version"])

  if (!is.null(repo_info) && pkg %in% repo_packages) {
    old_ver <- as.package_version(repo_info[pkg, "Version"])
    if (old_ver == new_ver) {
      next
    }

    old_tarball <- tarball(pkg, old_ver)
    unlink(file.path(webr_contrib_src, old_tarball))
    unlink(file.path(webr_contrib_bin, old_tarball))
  }

  need_update <- TRUE

  tarball_file <- tarball(pkg, new_ver)
  new_url <- paste0(cran_url, "src/contrib/", tarball_file)
  tarball_path <- file.path(webr_contrib_src, tarball_file)

  download.file(new_url, tarball_path)
  system2("./webr-build.sh", tarball_path)
}

if (need_update) {
  tools::write_PACKAGES(webr_contrib_src, verbose = TRUE)
  tools::write_PACKAGES(webr_contrib_bin, verbose = TRUE, type = "mac.binary")
}
