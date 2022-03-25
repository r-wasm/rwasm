packages <- commandArgs(trailingOnly = TRUE)

cran_info <- available.packages()
cran_info <- cran_info[packages, , drop = FALSE]
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

for (pkg in packages) {
  ver <- cran_info[pkg, "Version"]
  tar_gz <- tarball(pkg, ver)
  tarball_path <- file.path(webr_contrib_src, tar_gz)

  url <- paste0(cran_url, "src/contrib/", tar_gz)
  download.file(url, tarball_path)

  system2("./webr-build.sh", tarball_path)
}

tools::write_PACKAGES(webr_contrib_src, verbose = TRUE)
tools::write_PACKAGES(webr_contrib_bin, verbose = TRUE, type = "mac.binary")
