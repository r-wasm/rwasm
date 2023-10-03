make_library <- function(repo_dir = "./repo", lib_dir = './lib') {
  fs::dir_create(lib_dir)
  r_version <- getOption("rwasm.webr_version")
  contrib_bin <- fs::path(repo_dir, "bin", "emscripten", "contrib", r_version)

  pkgs <- fs::dir_ls(path = contrib_bin, glob = "*.tgz", recurse = FALSE)
  lapply(pkgs, function(pkg) { untar(pkg[[1]], exdir = lib_dir) })
  invisible(0)
}

make_vfs_image <- function(out_dir = './vfs', lib_dir = './lib', ...) {
  make_library(...)
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
    stop("An error occurred running `file_packager`:\n",
         paste(res, collapse = '\n'))
  }
}
