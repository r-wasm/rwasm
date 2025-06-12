#' Build one or more R packages for WebAssembly
#'
#' Downloads and builds the [R package references][pkgdepends::pkg_refs] given
#' by `packages`, compiling each package for use with WebAssembly and webR. The
#' resulting WebAssembly binary packages are written to `out_dir`.
#'
#' @param packages A character vector of one or more package references.
#' @param out_dir The output directory. Defaults to `"."`.
#' @param remotes A character vector of package references to prefer as a remote
#'   source. If `NA`, use a built-in list of references to packages pre-modified
#'   for use with webR. Defaults to `NULL`, meaning no preference over the usual
#'   remote sources.
#' @inheritParams add_pkg
#'
#' @importFrom pkgdepends new_pkg_download_proposal
#' @export
build <- function(
  packages,
  out_dir = ".",
  remotes = NULL,
  dependencies = FALSE,
  compress = TRUE
) {
  tmp_dir <- tempfile()
  on.exit(unlink(tmp_dir, recursive = TRUE))
  dir.create(tmp_dir)

  # Set up pkgdepends configuration
  config <- ppm_config
  config$dependencies <- dependencies

  # Resolve list of requested packages
  package_deps <- new_pkg_download_proposal(packages, config = config)
  package_deps <- package_deps$resolve()
  package_info <- package_deps$get_resolution()
  package_info <- package_info[!grepl("/Recommended/", package_info$target), ]
  package_info <- package_info[grepl("^source$", package_info$platform), ]

  packages <- prefer_remotes(package_info, remotes)

  for (n in seq_len(nrow(packages))) {
    pkg_row <- packages[n, ]
    pkg <- pkg_row$package

    # Download package source
    tarball_file <- basename(pkg_row$target)
    tarball_path <- fs::path(tmp_dir, tarball_file)
    make_remote_tarball(
      pkg_row$package,
      pkg_row$sources[[1]][[1]],
      tarball_path
    )

    wasm_build(pkg, tarball_path, out_dir, compress)
  }
}

# Download a remote source to a source tarball on disk
make_remote_tarball <- function(pkg, src, target) {
  tmp_dir <- tempfile()
  on.exit(unlink(tmp_dir, recursive = TRUE))
  dir.create(tmp_dir)

  is_local <- grepl("^file://", src)
  target <- fs::path_abs(target)

  # Obtain a copy of the R source and extract to a temporary directory
  if (is_local && fs::is_dir(gsub("^file://", "", src))) {
    fs::dir_copy(gsub("^file://", "", src), fs::path(tmp_dir, pkg))
  } else {
    source_tarball <- file.path(tmp_dir, "dest.tar.gz")
    download.file(src, source_tarball)

    result_code <- attr(
      suppressWarnings(untar(source_tarball, list = TRUE)),
      "status"
    )
    if (is.null(result_code) || result_code == 0L) {
      untar(
        source_tarball,
        exdir = file.path(tmp_dir, pkg),
        extras = "--strip-components=1"
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
  }

  # Recreate a new .tar.gz with the directory structure expected from
  # a source package
  withr::with_dir(
    tmp_dir,
    tar(target, files = pkg, compression = "gzip")
  )
}

# Build the given R package for WebAssembly
wasm_build <- function(pkg, tarball_path, contrib_bin, compress) {
  # Extract package source to a tempdir
  tmp_dir <- fs::path(tempfile())
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  dir.create(tmp_dir)
  untar(tarball_path, exdir = tmp_dir)

  # Ensure this package is a source package
  desc <- packageDescription(pkg, lib.loc = tmp_dir, fields = "Built")
  if (!is.na(desc)) {
    stop(paste0(
      "Unable to build Wasm package: '",
      pkg,
      "'. Source tarball at '",
      tarball_path,
      "' is a binary."
    ))
  }

  # Setup emconfigure wrapper
  configure_src <- system.file("configure", package = "rwasm")
  configure_orig <- fs::path(tmp_dir, pkg, "configure")
  configure_copy <- fs::path(tmp_dir, pkg, "configure.orig")
  if (fs::is_file(configure_orig)) {
    fs::file_copy(configure_orig, configure_copy)
    fs::file_copy(configure_src, configure_orig, overwrite = TRUE)
  }

  # Setup optional Makevars overrides
  configure_flag <- ""
  mkvars_dest <- fs::path(tmp_dir, pkg, "src")
  mkvars_src <- c(
    system.file("Makevars", paste0(pkg, ".mk"), package = "rwasm"),
    system.file("Makevars", paste0(pkg, ".in.mk"), package = "rwasm"),
    fs::path(tmp_dir, pkg, "src", "Makevars.webr"),
    fs::path(tmp_dir, pkg, "src", "Makevars.in.webr")
  )
  for (mk in mkvars_src) {
    if (fs::is_file(mk)) {
      message(paste("Using Makevars override:", mk))
      if (!grepl("\\.in\\.", mk)) {
        mkvars_dest <- fs::path(mkvars_dest, "Makevars")
        fs::file_copy(mk, mkvars_dest, overwrite = TRUE)
        configure_flag <- "--no-configure"
      } else {
        mkvars_dest <- fs::path(mkvars_dest, "Makevars.in")
        fs::file_copy(mk, mkvars_dest, overwrite = TRUE)
      }
      break
    }
  }
 

  # Setup environment for wasm compilation
  webr_root <- getOption("rwasm.webr_root")
  webr_version <- getOption("rwasm.webr_version")
  webr_vars <- system.file("webr-vars.mk", package = "rwasm")
  webr_profile <- system.file("webr-profile", package = "rwasm")
  sys_bin <- system.file("bin", package = "rwasm")
  webr_env <- c(
    paste0("BUILD_PLATFORM=", R.Version()$platform),
    paste0("R_PROFILE_USER=", webr_profile),
    paste0("R_MAKEVARS_USER=", webr_vars),
    paste0("WEBR_VERSION=", webr_version),
    paste0("WEBR_ROOT=", webr_root),
    sprintf("PATH='%s:%s/host/bin:%s'", sys_bin, webr_root, Sys.getenv("PATH")),
    sprintf("PKG_CONFIG_PATH=%s/wasm/lib/pkgconfig", webr_root),
    sprintf("EM_PKG_CONFIG=%s", Sys.which("pkg-config")),
    sprintf("EM_PKG_CONFIG_PATH=%s/wasm/lib/pkgconfig", webr_root)
  )
 
  if ("RcppParallel" %in% pak::pkg_deps(pkg)$package) {
    rcppparallel_tar <- file.path(tmp_dir, "rcppparallel.tgz")
    download.file(
      "https://rcppcore.r-universe.dev/bin/emscripten/contrib/4.5/RcppParallel_5.1.10.9000.tgz",
      rcppparallel_tar,
      mode = "wb"
    )
    untar(rcppparallel_tar)
    webr_env <- c(
      webr_env,
      paste0("TBB_INC=", file.path(tmp_dir, "RcppParallel", "include")),
      paste0("TBB_LIB=", file.path(tmp_dir, "RcppParallel", "lib"))
    )
  }

  # Need to use an empty library otherwise R might try to load wasm packages
  # from the library and fail
  lib_dir <- tempfile()
  on.exit(unlink(lib_dir, recursive = TRUE), add = TRUE)
  dir.create(lib_dir)

  # Try to ensure that package dependencies are installed in host R
  try({
    pak::pkg_install(paste0("deps::", tarball_path), ask = FALSE)
  })

  # Prefer to use system R, if it exists
  host_r_bin <- if (Sys.which("R") != "") {
    Sys.which("R")
  } else {
    fs::path(
      getOption("rwasm.webr_root"),
      "host",
      paste0("R-", webr_version),
      "bin",
      "R"
    )
  }

  # Build the package
  status <- withr::with_dir(
    tmp_dir,
    system2(
      host_r_bin,
      args = c(
        "CMD",
        "INSTALL",
        "--build",
        paste0("--library=", lib_dir),
        pkg,
        "--no-docs",
        "--no-html",
        "--no-test-load",
        "--no-staged-install",
        "--no-byte-compile",
        configure_flag
      ),
      env = webr_env
    )
  )
  if (status != 0) {
    stop(paste0("Building wasm binary for package '", pkg, "' failed."))
  }

  # Copy to local CRAN-like repo directory
  bin_path <- c(
    fs::dir_ls(tmp_dir, glob = "*.tgz"),
    fs::dir_ls(tmp_dir, glob = "*.tar.gz")
  )[[1]]
  bin_ver <- packageDescription(pkg, lib.loc = lib_dir, fields = "Version")
  bin_dest <- fs::path(contrib_bin, paste0(pkg, "_", bin_ver, ".tgz"))
  fs::file_copy(bin_path, bin_dest, overwrite = TRUE)

  if (compress) {
    # Use binary .tgz file to build Emscripten filesystem image metadata
    add_tar_index(bin_dest, strip = 1)
  } else {
    # Build an uncompressed Emscripten filesystem image for the package
    tmp_bin_dir <- fs::path(tempfile())
    on.exit(unlink(tmp_bin_dir, recursive = TRUE), add = TRUE)
    untar(bin_dest, exdir = tmp_bin_dir)
    file_packager(
      fs::dir_ls(tmp_bin_dir)[[1]],
      contrib_bin,
      fs::path_file(bin_dest),
      compress = FALSE
    )
  }

  invisible(NULL)
}
