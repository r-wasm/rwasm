args <- commandArgs(trailingOnly = TRUE)

if (length(args)) {
  packages <- args
} else {
  packages <- unique(readLines("repo-packages"))
}

writeLines(
  sprintf("Processing %d package(s).", length(packages))
)

r_version <- Sys.getenv("R_VERSION")
if (file.exists("repo/src/contrib/PACKAGES")) {
  # Check available packages in the binary folder rather than the
  # source folder so that we retry building failed packages until they
  # succeed
  repo_info <- available.packages(
    paste0("file:repo/bin/emscripten/contrib/", r_version)
  )
  repo_packages <- rownames(repo_info)
} else {
  repo_info <- NULL
}

cran_url <- getOption("repos")[["CRAN"]]
webr_contrib_src <- file.path("repo", "src", "contrib")
webr_contrib_bin <- file.path("repo", "bin", "emscripten", "contrib", r_version)

# Ensure both rlang and pkgdepends can be used
host_packages <- installed.packages()
if (!"rlang" %in% host_packages || !"pkgdepends" %in% host_packages) {
    install.packages(c("rlang", "pkgdepends"))
}

stopifnot(
  rlang::is_string(cran_url),
  dir.exists(webr_contrib_src),
  nzchar(r_version)
)


# Download all missing or outdated remotes to the repo
remotes <- unique(readLines("repo-remotes"))
remotes_deps <- pkgdepends::new_pkg_download_proposal(remotes)
remotes_deps$resolve()
remotes_info <- remotes_deps$get_resolution()
remotes_info <- remotes_info[remotes_info$type != "standard", ]
remotes_packages <- remotes_info[["package"]]

# Download a remote source to src/contrib
make_remote_tarball <- function(pkg, url, target) {
  tmp_dir <- tempfile()
  on.exit(unlink(tmp_dir, recursive = TRUE))
  dir.create(tmp_dir)

  # Remove all existing tarballs to avoid conflicting versions in case
  # old remotes have already been downloaded
  unlink(list.files(webr_contrib_src, paste0(pkg, "_.*\\.tar\\.gz$")))

  source_tarball <- file.path(tmp_dir, "dest.tar.gz")
  download.file(url, source_tarball)

  # Recreate a new .tar.gz with the directory structure expected from
  # a source package
  untar(
    source_tarball,
    exdir = file.path(tmp_dir, pkg),
    extra = "--strip-components=1"
  )
  unlink(source_tarball)

  repo_tarball <- file.path(normalizePath("repo"), target)

  withr::with_dir(
    tmp_dir,
    tar(repo_tarball, compression = "gzip")
  )
}

tarball <- function(pkg, ver) {
  paste0(pkg, "_", ver,  ".tar.gz")
}

cran_info <- available.packages()
cran_packages <- packages[!(packages %in% remotes_packages)]
versions <- cran_info[cran_packages, "Version", drop = TRUE]
names(versions) <- cran_packages
versions[remotes_packages] <- remotes_info[["version"]]

need_update <- FALSE

for (pkg in packages) {
  new_ver_string <- versions[[pkg]]
  new_ver <- as.package_version(new_ver_string)

  if (!is.null(repo_info) && pkg %in% repo_packages) {
    old_ver <- as.package_version(repo_info[pkg, "Version"])
    if (old_ver == new_ver) {
      next
    }

    old_tarball <- tarball(pkg, old_ver)
    unlink(file.path(webr_contrib_src, old_tarball))
    unlink(file.path(webr_contrib_bin, old_tarball))
  }

  if (pkg %in% remotes_packages) {
    remote_info <- remotes_info[match(pkg, remotes_info[["package"]]), ]
    remote_target <- remote_info[["target"]]

    if (!file.exists(file.path("repo", remote_target))) {
      need_update <- TRUE

      make_remote_tarball(
        remote_info[["package"]],
        remote_info[["sources"]][[1]][[1]],
        remote_target
      )
    }

    tarball_file <- basename(remote_target)
    tarball_path <- file.path(webr_contrib_src, tarball_file)
  } else {
    tarball_file <- tarball(pkg, new_ver_string)
    tarball_path <- file.path(webr_contrib_src, tarball_file)
    new_url <- paste0(cran_url, "src/contrib/", tarball_file)
    download.file(new_url, tarball_path)
  }

  if (!pkg %in% host_packages) {
    install.packages(pkg)
  }

  if (!system2("./webr-build.sh", tarball_path)) {
    need_update <- TRUE
  }
}

if (need_update) {
  tools::write_PACKAGES(webr_contrib_src, verbose = TRUE)
  tools::write_PACKAGES(webr_contrib_bin, verbose = TRUE, type = "mac.binary")
}
