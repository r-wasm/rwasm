#' Create an R package library
#'
#' Extracts all R packages contained in the repository directory `repo_dir` and
#' writes them to a library directory `lib_dir`.
#'
#' The `lib_dir` directory will be created if it does not already exist.
#'
#' The `strip` argument may be used to strip certain directories from packages
#' installed to the library directory `lib_dir`. This can be used to reduce the
#' total library file size by removing directories that are not strictly
#' necessary for the R package to run, such as directories containing
#' documentation and vignettes.
#'
#' @inheritParams add_pkg
#' @param lib_dir Package library output directory. Defaults to `"./lib"`.
#' @param strip A character vector of directories to strip from each R package.
#'
#' @export
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

  invisible(NULL)
}

#' Add Emscripten filesystem images to an R package repository
#'
#' Creates an Emscripten filesystem image for each R package that exists in the
#' package repository directory `repo_dir`.
#'
#' Each filesystem image is generated using Emscripten's [file_packager()] tool
#' and the output `.data` and `.js.metadata` filesystem image files are written
#' to the repository in the same directory as the package binary `.tgz` files.
#'
#' The resulting filesystem images may then be used by webR to download and
#' install R packages by mounting the `.data` images to the Emscripten virtual
#' filesystem.
#'
#' When `compress` is `TRUE`, an additional file with extension `".data.gz"` is
#' also output containing a compressed version of the filesystem data.
#'
#' @inheritParams add_pkg
#'
#' @export
make_vfs_repo <- function(repo_dir = "./repo", compress = FALSE) {
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
    tmp_dir <- fs::path(tempfile())
    untar(pkg, exdir = tmp_dir)
    file_packager(
      fs::dir_ls(tmp_dir)[[1]],
      contrib_bin,
      fs::path_file(pkg),
      compress
    )
    unlink(tmp_dir, recursive = TRUE)
  })

  invisible(NULL)
}

#' Create an Emscripten filesystem image of an R package library
#'
#' Extracts all binary R packages contained in the repository directory
#' `repo_dir` and creates an Emscripten filesystem image containing the
#' resulting package library.
#'
#' A single filesystem image is generated using Emscripten's [file_packager()]
#' tool and the output `.data` and `.js.metadata` filesystem image files are
#' written to the directory `out_dir`.
#'
#' When `compress` is `TRUE`, an additional file with extension `".data.gz"` is
#' also output containing a compressed version of the filesystem data.
#'
#' The resulting image can be downloaded by webR and mounted on the Emscripten
#' virtual filesystem as an efficient way to provide a pre-configured R library,
#' without installing each R package individually.
#'
#' @param out_name A character string for the output library image filename.
#' @inherit add_pkg
#' @inherit file_packager
#' @inheritDotParams make_library strip
#'
#' @export
make_vfs_library <- function(out_dir = "./vfs",
                             out_name = "library.data",
                             repo_dir = "./repo",
                             compress = FALSE,
                             ...) {
  lib_dir <- fs::path(tempfile())
  lib_abs <- fs::path_abs(lib_dir)
  on.exit(unlink(lib_dir, recursive = TRUE), add = TRUE)

  make_library(repo_dir, lib_dir = lib_dir, ...)
  file_packager(lib_abs, out_dir, out_name = out_name, compress)
}


#' Create an Emscripten filesystem image
#'
#' Uses Emscripten's `file_packager` tool to build an Emscripten filesystem
#' image that can be mounted by webR. The filesystem image may contain arbitrary
#' data that will be made available for use by the WebAssembly R process once
#' mounted.
#'
#' Outputs at least two files (named by `out_name`) in the `out_dir` directory:
#' a data file with extension `".data"`, and a metadata file with extension
#' `".js.metadata"`. Both files should be hosted online so that their URL can be
#' provided to webR for mounting on the Emscripten virtual filesystem.
#'
#' When `compress` is `TRUE`, an additional file with extension `".data.gz"` is
#' also output containing a compressed version of the filesystem data. The
#' metadata file is also changed to reflect the availability of a compressed
#' version of the data.
#'
#' @param in_dir Directory to be packaged into the filesystem image.
#' @param out_dir Directory in which to write the output image files. Defaults
#'   to `"./vfs"`.
#' @param out_name A character string for the output image base filename. If
#'   `NULL`, defaults to the final component of the input directory path.
#' @param compress Logical. If `TRUE`, a compressed version of the filesystem
#' data is included in the output. Defaults to `FALSE`.
#' @export
file_packager <- function(in_dir,
                          out_dir = "./vfs",
                          out_name = NULL,
                          compress = FALSE) {
  fs::dir_create(out_dir)

  if (is.null(out_name)) {
    out_name <- fs::path_file(in_dir)
  }

  data_file <- fs::path_ext_set(out_name, ".data")
  js_file <- fs::path_ext_set(out_name, ".js")
  message(paste("Packaging:", data_file))

  file_packager <- fs::path(
    getOption("rwasm.emscripten_root"), "tools", "file_packager"
  )

  # Pack the contents of in_dir with Emscripten's `file_packager`
  # Capture stdout/stderr to silence an Emscripten developer warning
  res <- withr::with_dir(
    out_dir,
    system2(
      file_packager,
      args = c(
        data_file, "--preload", sprintf("'%s@/'", in_dir),
        "--separate-metadata", sprintf("--js-output='%s'", js_file)
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  # If there is some problem, print the output of `file_packager` and stop
  status <- attr(res, "status")
  if (!is.null(status) && status != 0) {
    stop(
      "An error occurred running `file_packager`:\n",
      paste(res, collapse = "\n")
    )
  }

  if (compress) {
    compress_vfs_image(out_dir, out_name)
  }

  # Remove the .js file, we don't need it when using Emscripten's FS.mount()
  unlink(fs::path(out_dir, js_file))
  invisible(NULL)
}

compress_vfs_image <- function(vfs_dir, vfs_name) {
  data_path <- fs::path(vfs_dir, fs::path_ext_set(vfs_name, ".data"))
  gz_path <- fs::path(vfs_dir, fs::path_ext_set(vfs_name, ".data.gz"))
  meta_path <- fs::path(vfs_dir, fs::path_ext_set(vfs_name, ".js.metadata"))

  # gzip compress .data file
  message(paste("Compressing:", fs::path_file(gz_path)))
  data_size <- fs::file_size(data_path)
  data_raw <- readBin(data_path, "raw", data_size)
  gz_con <- gzfile(gz_path, "wb")
  writeBin(data_raw, gz_con, useBytes = TRUE)
  close(gz_con)

  # Remove the original .data file
  unlink(data_path)

  # Add `gzip: true` to metadata
  meta_json <- readLines(meta_path, warn = FALSE)
  metadata <- jsonlite::fromJSON(meta_json)
  metadata$gzip <- TRUE
  writeLines(jsonlite::toJSON(metadata, auto_unbox = TRUE), meta_path)

  invisible(NULL)
}
