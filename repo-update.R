webr_info <- available.packages(repo = "file:repo")
webr_packages <- rownames(webr_info)

cran_info <- available.packages()
cran_info <- cran_info[webr_packages, , drop = FALSE]
cran_url <- getOption("repos")[["CRAN"]]

webr_contrib_src <- file.path("repo", "src", "contrib")
webr_contrib_bin <- file.path("repo", "bin", "emscripten", "contrib", r_version)

stopifnot(
  identical(webr_packages, rownames(cran_info)),
  rlang::is_string(cran_url),
  dir.exists(webr_contrib_src)
)

tarball <- function(pkg, ver) {
  paste0(pkg, "_", ver,  ".tar.gz")
}

need_update <- FALSE

for (pkg in webr_packages) {
  old_ver <- webr_info[pkg, "Version"]
  new_ver <- cran_info[pkg, "Version"]

  if (old_ver < new_ver) {
    need_update <- TRUE

    old_tarball <- tarball(pkg, old_ver)
    new_tarball <- tarball(pkg, new_ver)

    unlink(file.path(webr_contrib_src, old_tarball))

    new_url <- paste0(cran_url, "src/contrib/", new_tarball)
    tarball_path <- file.path(webr_contrib_src, new_tarball)
    download.file(new_url, tarball_path)

    system2("./webr-build.sh", tarball_path)
  }
}

if (need_update) {
  tools::write_PACKAGES(webr_contrib_src, verbose = TRUE)
  tools::write_PACKAGES(webr_contrib_bin, verbose = TRUE, type = "mac.binary")
}
