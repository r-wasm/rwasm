make_library <- function(repo_dir = "./repo", lib_dir = "./lib", strip = NULL) {
  fs::dir_create(lib_dir)
  r_version <- R_system_version(getOption("rwasm.webr_version"))
  contrib_bin <- fs::path(
    repo_dir, "bin", "emscripten", "contrib",
    paste0(r_version$major, ".", r_version$minor)
  )

  pkgs <- fs::dir_ls(contrib_bin, glob = "*.tgz", recurse = FALSE)
  lapply(pkgs, function(pkg) {
    untar(pkg, exdir = lib_dir)
  })

  # Strip out directories requested to be removed
  fs::dir_walk(lib_dir, type = "directory", function(pkg_dir) {
    fs::dir_walk(pkg_dir, type = "directory", function(dir) {
      if (fs::path_file(dir) %in% strip) {
        fs::dir_delete(fs::path(dir))
      }
    })
  })

  invisible(0)
}

make_vfs_repo <- function(repo_dir = "./repo") {
  r_version <- R_system_version(getOption("rwasm.webr_version"))
  contrib_bin <- fs::path(
    repo_dir, "bin", "emscripten", "contrib",
    paste0(r_version$major, ".", r_version$minor)
  )

  # Clean up any previously created vfs images
  pkg_data <- fs::dir_ls(contrib_bin, glob = "*.data")
  pkg_meta <- fs::dir_ls(contrib_bin, glob = "*.metadata")
  lapply(c(pkg_data, pkg_meta), function(f) {
    fs::file_delete(f)
  })

  # Create vfs images for each package
  pkgs <- fs::dir_ls(contrib_bin, glob = "*.tgz", recurse = FALSE)
  lapply(pkgs, function(pkg) {
    # Extract the package contents
    tmp_dir <- fs::path(tempfile())
    untar(pkg, exdir = tmp_dir)

    pkg_path <- fs::dir_ls(tmp_dir)[[1]]
    message(paste("Packaging:", fs::path_file(pkg_path)))
    pkg_file <- fs::path_file(pkg)
    data_file <- fs::path_ext_set(pkg_file, ".data")
    meta_file <- fs::path_ext_set(pkg_file, ".js.metadata")
    js_file <- fs::path_ext_set(pkg_file, ".js")

    file_packager <- fs::path(
      getOption("rwasm.emsdk_root"),
      "upstream",
      "emscripten",
      "tools",
      "file_packager"
    )

    # Pack the package contents with Emscripten file_packager
    withr::with_dir(
      tmp_dir,
      system2(file_packager,
        args = c(
          data_file, "--preload", paste0("'", pkg_path, "@/'"),
          "--separate-metadata", paste0("--js-output='", js_file, "'")
        ),
        stdout = TRUE,
        stderr = TRUE
      )
    )
    fs::file_copy(
      fs::path(tmp_dir, data_file),
      fs::path(contrib_bin, data_file),
      overwrite = TRUE
    )
    fs::file_copy(
      fs::path(tmp_dir, meta_file),
      fs::path(contrib_bin, meta_file),
      overwrite = TRUE
    )
    unlink(tmp_dir, recursive = TRUE)
  })

  invisible(0)
}

make_vfs_image <- function(out_dir = "./vfs", ...) {
  lib_dir <- fs::path(tempfile())
  on.exit(unlink(lib_dir, recursive = TRUE), add = TRUE)

  make_library(lib_dir = lib_dir, ...)
  fs::dir_create(out_dir)

  file_packager <- fs::path(
    getOption("rwasm.emsdk_root"),
    "upstream",
    "emscripten",
    "tools",
    "file_packager"
  )

  lib_abs <- fs::path_abs(lib_dir)
  res <- withr::with_dir(
    out_dir,
    system2(file_packager,
      args = c(
        "library.data", "--preload", paste0("'", lib_abs, "@/'"),
        "--separate-metadata", "--js-output='library.js'"
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  status <- attr(res, "status")
  if (!is.null(status) && status != 0) {
    stop(
      "An error occurred running `file_packager`:\n",
      paste(res, collapse = "\n")
    )
  }
}
