make_library <- function(repo_dir = "./repo", lib_dir = './lib') {
  fs::dir_create(lib_dir)
  r_version <- getOption("rwasm.webr_version")
  contrib_bin <- fs::path(repo_dir, "bin", "emscripten", "contrib", r_version)

  pkgs <- fs::dir_ls(path = contrib_bin, glob = "*.tgz", recurse = FALSE)
  lapply(pkgs, function(pkg) { untar(pkg[[1]], exdir = lib_dir) })
  invisible(0)
}
