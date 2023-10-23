# Build the given R package for WebAssembly
wasm_build <- function(pkg, tarball_path, contrib_bin) {
  # Extract package source to a tempdir
  tmp_dir <- fs::path(tempfile())
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  dir.create(tmp_dir)
  untar(tarball_path, exdir = tmp_dir)

  # Ensure this package is a source package
  desc <- packageDescription(pkg, lib.loc = tmp_dir, fields = "Built")
  if (!is.na(desc)) {
    warning(paste0(
      "Unable to build Wasm package: '", pkg,
      "'. Source tarball at '", tarball_path, "' is a binary."
    ))
    return(1)
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
  webr_env <- c(
    paste0("R_PROFILE_USER=", webr_profile),
    paste0("R_MAKEVARS_USER=", webr_vars),
    paste0("WEBR_VERSION=", webr_version),
    paste0("WEBR_ROOT=", webr_root),
    sprintf("PATH='%s/wasm/bin:%s'", webr_root, Sys.getenv("PATH")),
    sprintf("PKG_CONFIG_PATH=%s/wasm/lib/pkgconfig", webr_root)
  )

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
    system2(host_r_bin,
      args = c(
        "CMD", "INSTALL", "--build", paste0("--library=", lib_dir), pkg,
        "--no-docs", "--no-html", "--no-test-load", "--no-staged-install",
        "--no-byte-compile", configure_flag
      ),
      env = webr_env
    )
  )
  if (status != 0) {
    return(status)
  }

  # Copy to local CRAN-like repo directory
  bin_path <- c(
    fs::dir_ls(tmp_dir, glob = "*.tgz"),
    fs::dir_ls(tmp_dir, glob = "*.tar.gz")
  )[[1]]
  bin_ver <- packageDescription(pkg, lib.loc = lib_dir, fields = "Version")
  bin_dest <- fs::path(contrib_bin, paste0(pkg, "_", bin_ver, ".tgz"))
  fs::file_copy(bin_path, bin_dest, overwrite = TRUE)

  status
}
