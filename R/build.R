# Build the given R package for WebAssembly
wasm_build <- function(pkg, tarball_path, contrib_bin) {
  # Extract package source to a tempdir
  tmp_dir <- fs::path(tempfile())
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  dir.create(tmp_dir)
  untar(tarball_path, exdir = tmp_dir)

  # Setup optional Makevars overrides
  configure_flag <- ""
  mkvars_dest <- fs::path(tmp_dir, pkg, "src", "Makevars")
  mkvars_src <- c(
    system.file("Makevars", paste0(pkg, ".mk"), package = "rwasm"),
    fs::path(tmp_dir, pkg, "src", "Makevars.webr")
  )
  for (mk in mkvars_src) {
    if (fs::is_file(mk)) {
      message(paste("Using Makevars override:", mk))
      fs::file_copy(mk, mkvars_dest, overwrite = TRUE)
      configure_flag <- "--no-configure"
      break
    }
  }

  # Setup environment for wasm compilation
  webr_vars <- system.file("webr-vars.mk", package = "rwasm")
  webr_profile <- system.file("webr-profile", package = "rwasm")
  webr_env <- c(
    paste0("R_PROFILE_USER=", webr_profile),
    paste0("R_MAKEVARS_USER=", webr_vars),
    paste0("WEBR_VERSION=", getOption("rwasm.webr_version")),
    paste0("WEBR_ROOT=", getOption("rwasm.webr_root")),
    paste0(
      "PATH=\"", getOption("rwasm.webr_root"),
      "/wasm/bin:", Sys.getenv("PATH"), "\""
    ),
    paste0(
      "PKG_CONFIG_PATH=",
      getOption("rwasm.webr_root"),
      "/wasm/lib/pkgconfig"
    )
  )

  # Need to use an empty library otherwise R might try to load wasm packages
  # from the library and fail
  lib_dir <- tempfile()
  on.exit(unlink(lib_dir, recursive = TRUE), add = TRUE)
  dir.create(lib_dir)

  # Ensure package dependencies are installed to host R
  pak::pkg_install(paste0("deps::", tarball_path))

  # Prefer to use system R, if it exists
  host_r_bin <- if (Sys.which("R") != "") {
    Sys.which("R")
  } else {
    fs::path(
      getOption("rwasm.webr_root"),
      "host",
      paste0("R-", getOption("rwasm.webr_version")),
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
