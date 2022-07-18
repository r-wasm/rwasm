webr_install <- function(packages, repos = "file:/repo", lib = NULL) {
  if (is.null(lib)) {
    lib <- .libPaths()[[1]]
  }
  info <- available.packages(repos = repos, type = "source")
  deps <- unlist(tools::package_dependencies(packages, info), use.names = FALSE)
  deps <- unique(c(packages, deps))

  for (dep in deps) {
    if (requireNamespace(dep, quietly = TRUE)) {
      next
    }

    ver <- as.character(getRversion())
    ver <- gsub("\\.[^.]+$", "", ver)
    bin_suffix <- sprintf("bin/emscripten/contrib/%s", ver)

    repo <- info[dep, "Repository"]
    repo <- sub("src/contrib", bin_suffix, repo, fixed = TRUE)
    repo <- sub("file:", "", repo, fixed = TRUE)

    pkg_ver <- info[dep, "Version"]
    path <- file.path(repo, paste0(dep, "_", pkg_ver, ".tgz"))

    tmp <- tempfile()
    download.file(path, tmp)

    untar(
      path,
      exdir = lib,
      tar = "internal",
      extras = "--no-same-permissions"
    )
  }

  invisible(NULL)
}
