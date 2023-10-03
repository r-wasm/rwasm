add_pkg <- function(...) {
  update_repo(...)
}

# Download a remote source to src/contrib
make_remote_tarball <- function(pkg, url, target, contrib_src) {
  tmp_dir <- tempfile()
  on.exit(unlink(tmp_dir, recursive = TRUE))
  dir.create(tmp_dir)

  # Remove all existing tarballs to avoid conflicting versions in case
  # old remotes have already been downloaded
  unlink(list.files(contrib_src, paste0(pkg, "_.*\\.tar\\.gz$")))

  source_tarball <- file.path(tmp_dir, "dest.tar.gz")
  download.file(url, source_tarball)

  # Recreate a new .tar.gz with the directory structure expected from
  # a source package
  result_code <- attr(
    suppressWarnings(untar(source_tarball, list = TRUE)),
    "status"
  )
  if (is.null(result_code) || result_code == 0L) {
    untar(
      source_tarball,
      exdir = file.path(tmp_dir, pkg),
      extra = "--strip-components=1"
    )
  } else {
    # Try to unzip if untar fails
    # Get root folder name, necessary as it won't unzip as `pkg`
    folder_name <- unzip(source_tarball, list = TRUE)$Name[[1]]
    zip::unzip(source_tarball, exdir = file.path(tmp_dir))
    # rename folder_name to `pkg`
    file.rename(file.path(tmp_dir, folder_name), file.path(tmp_dir, pkg))
  }
  unlink(source_tarball)

  repo_tarball <- file.path(normalizePath("repo"), target)
  withr::with_dir(
    tmp_dir,
    tar(repo_tarball, files = pkg, compression = "gzip")
  )
}

update_repo <- function(packages, remotes = NULL, repo_dir = "./repo") {
  r_version <- getOption("rwasm.webr_version")

  writeLines(sprintf("Processing %d package(s).", length(packages)))

  cran_url <- getOption("repos")[["CRAN"]]
  cran_url <- gsub("/$", "", cran_url)
  host_packages <- row.names(installed.packages())
  cran_info <- available.packages()

  # Create contrib paths
  contrib_src <- fs::path(repo_dir, "src", "contrib")
  contrib_bin <- fs::path(repo_dir, "bin", "emscripten", "contrib", r_version)
  fs::dir_create(contrib_src)
  fs::dir_create(contrib_bin)

  if (fs::is_file(fs::path(contrib_src, "PACKAGES"))) {
    # Check available packages in the binary folder rather than the
    # source folder so that we retry building failed packages until they
    # succeed
    repo_info <- available.packages(
      paste0("file:", contrib_bin)
    )
    repo_packages <- rownames(repo_info)
  } else {
    repo_info <- NULL
  }

  if (is.null(remotes)) {
    remotes <- system.file("webr-remotes", package = "rwasm")
  }

  remotes <- unique(readLines(remotes))
  remotes_deps <- pkgdepends::new_pkg_download_proposal(remotes)
  remotes_deps$resolve()
  remotes_info <- remotes_deps$get_resolution()

  # Ignore binaries in remotes resolution
  remotes_info <- remotes_info[remotes_info$needscompilation, ]
  remotes_packages <- remotes_info[["package"]]

  # Include all dependencies in build plan
  deps <- pkgdepends::new_pkg_deps(packages)
  deps$resolve()
  packages <- unique(deps$get_resolution()$package)

  # Check for any packages not found in repo-remotes or CRAN
  cran_packages <- packages[!(packages %in% remotes_packages)]
  if (any(!(cran_packages %in% rownames(cran_info)))) {
    not_found <- cran_packages[!(cran_packages %in% rownames(cran_info))]
    rlang::abort(c(
      "The following packages cannot be found in remotes nor CRAN:",
      paste(not_found, collapse = ", ")
    ))
  }

  versions <- cran_info[cran_packages, "Version", drop = TRUE]
  names(versions) <- cran_packages
  versions[remotes_packages] <- remotes_info[["version"]]

  need_update <- FALSE
  for (pkg in packages) {
    tarball <- function(pkg, ver) {
      paste0(pkg, "_", ver, ".tar.gz")
    }

    # Get version for this version of the package
    new_ver_string <- versions[[pkg]]
    new_ver <- as.package_version(new_ver_string)

    # If the package already exists in the given repo
    if (!is.null(repo_info) && pkg %in% repo_packages) {
      # Skip building this package if the versions match
      old_ver <- as.package_version(repo_info[pkg, "Version"])
      if (old_ver == new_ver) {
        next
      }

      # Remove the old package from disk
      old_tarball <- tarball(pkg, old_ver)
      unlink(fs::path(contrib_src, old_tarball))
      unlink(fs::path(contrib_bin, old_tarball))
    }

    # Download the new package
    if (pkg %in% remotes_packages) {
      remote_info <- remotes_info[match(pkg, remotes_info[["package"]]), ]
      remote_target <- remote_info[["target"]]

      if (!file.exists(file.path("repo", remote_target))) {
        need_update <- TRUE
        make_remote_tarball(
          remote_info[["package"]],
          remote_info[["sources"]][[1]][[1]],
          remote_target,
          contrib_src
        )
      }

      tarball_file <- basename(remote_target)
      tarball_path <- fs::path(contrib_src, tarball_file)
    } else {
      tarball_file <- tarball(pkg, new_ver_string)
      tarball_path <- fs::path(contrib_src, tarball_file)

      # Ensure we're getting true source packages from PPM
      ppm_source_url <- "https://packagemanager.posit.co/cran/latest"
      new_url <- paste0(ppm_source_url, "/src/contrib/", tarball_file)
      download.file(new_url, tarball_path)
    }

    wasm_build(pkg, tarball_path, contrib_bin)
    need_update <- TRUE
  }

  if (need_update) {
    tools::write_PACKAGES(contrib_src, verbose = TRUE)
    tools::write_PACKAGES(contrib_bin, verbose = TRUE, type = "mac.binary")
  }
}
