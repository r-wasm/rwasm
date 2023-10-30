# Ensure that we're getting CRAN source packages from PPM, rather than binaries
ppm_config <- list(
  cran_mirror = "https://packagemanager.posit.co/cran/latest",
  platforms = "source"
)

#' Add all packages from a CRAN-like repository to a package repository
#'
#' Downloads and builds all available source R packages from the R package
#' repositories given by `repos`, compiling each package for use with
#' WebAssembly and webR. The resulting WebAssembly binary packages are added to
#' the repository directory `repo_dir`. The repository directory will be created
#' if it does not already exist.
#'
#' @param repos A character vector containing the base URL(s) of CRAN-like R
#'   package repositories. Defaults to the Posit Package Manager CRAN mirror.
#' @param skip A character string containing a regular expression matching names
#'   of packages to skip. Defaults to `FALSE`, meaning keep all packages.
#' @inheritDotParams add_pkg -packages
#'
#' @importFrom dplyr select rename mutate filter
#' @importFrom rlang .data
#' @export
add_repo <- function(repos = ppm_config$cran_mirror, skip = FALSE, ...) {
  # Avoid running pkgdepends on all of CRAN. Instead, build our own info
  pkgs <- as.data.frame(available.packages(repos = repos))
  package_info <- pkgs |>
    select(.data$Package, .data$Version, .data$Repository) |>
    rename(package = .data$Package, version = .data$Version) |>
    filter(!grepl(skip, .data$package)) |>
    mutate(
      sources = as.list(sprintf(
        "%s/%s_%s.tar.gz",
        .data$Repository, .data$package, .data$version
      )),
      target = sprintf(
        "src/contrib/%s_%s.tar.gz", .data$package, .data$version
      ),
      ref = .data$package,
      status = "OK"
    )
  update_repo(package_info, ...)
}

#' Add one or more packages from a file
#'
#' Downloads and builds the list of [R package references][pkgdepends::pkg_refs]
#' in the file `list_file`, compiling each package for use with WebAssembly and
#' webR. The resulting WebAssembly binary packages are added to the repository
#' directory `repo_dir`. The repository directory will be created if it does not
#' already exist.
#'
#' The R package references should be listed in the file `list_file`, one line
#' per package reference.
#'
#' @param list_file Path to a file containing a list of R package references.
#' @inheritDotParams add_pkg -packages
#'
#' @export
add_list <- function(list_file, ...) {
  pkgs <- unique(readLines(list_file))
  add_pkg(pkgs, ...)
}

#' Add R package reference(s) to a package repository
#'
#' Downloads and builds the [R package references][pkgdepends::pkg_refs] given
#' by `packages`, compiling each package for use with WebAssembly and webR. The
#' resulting WebAssembly binary packages are added to the repository directory
#' `repo_dir`. The repository directory will be created if it does not already
#' exist.
#'
#' @param packages A character vector of one or more package references.
#' @param remotes A character vector of package references to prefer as a remote
#'   source. If `NULL`, use a built-in list of references to packages
#'   pre-modified for use with webR.
#' @param repo_dir The package repository directory. Defaults to `"./repo"`.
#' @param dependencies Dependency specification for packages to additionally
#' add to the repository. Defaults to `NA`, meaning add only the required
#' dependencies. If `FALSE`, adds no additional packages. See
#' [pkgdepends::as_pkg_dependencies] for details.
#'
#' @importFrom dplyr rows_update select
#' @importFrom pkgdepends new_pkg_download_proposal
#' @export
add_pkg <- function(packages,
                    remotes = NULL,
                    repo_dir = "./repo",
                    dependencies = NA) {
  # Set up pkgdepends configuration
  config <- ppm_config
  config$dependencies <- dependencies

  # Resolve list of requested packages
  package_deps <- new_pkg_download_proposal(packages, config = config)
  package_deps <- package_deps$resolve()
  package_info <- package_deps$get_resolution()
  package_info <- package_info[!grepl("/Recommended/", package_info$target), ]

  update_repo(package_info, remotes, repo_dir)
}

#' Remove R package(s) from a package repository
#'
#' @param packages A character vector of one or more package names.
#' @inheritParams add_pkg
#'
#' @export
rm_pkg <- function(packages, repo_dir = "./repo") {
  r_version <- R_system_version(getOption("rwasm.webr_version"))
  contrib_src <- fs::path(repo_dir, "src", "contrib")
  contrib_bin <- fs::path(
    repo_dir, "bin", "emscripten", "contrib",
    paste0(r_version$major, ".", r_version$minor)
  )

  for (pkg in packages) {
    src <- fs::dir_ls(contrib_src, glob = paste0(contrib_src, "/", pkg, "_*"))
    bin <- fs::dir_ls(contrib_bin, glob = paste0(contrib_bin, "/", pkg, "_*"))
    fs::file_delete(c(src, bin))
  }

  update_packages(contrib_src, contrib_bin)
}

#' Write the `PACKAGES` file for a package repository
#'
#' @inheritParams add_pkg
#' @export
write_packages <- function(repo_dir = "./repo") {
  r_version <- R_system_version(getOption("rwasm.webr_version"))
  contrib_src <- fs::path(repo_dir, "src", "contrib")
  contrib_bin <- fs::path(
    repo_dir, "bin", "emscripten", "contrib",
    paste0(r_version$major, ".", r_version$minor)
  )
  update_packages(contrib_src, contrib_bin)
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

  repo_tarball <- file.path(normalizePath("repo"), target)
  withr::with_dir(
    tmp_dir,
    tar(repo_tarball, files = pkg, compression = "gzip")
  )
}

# Build packages and update a CRAN-like repo on disk
#' @importFrom rlang .data
update_repo <- function(package_info,
                        remotes = NULL,
                        repo_dir = "./repo") {
  r_version <- R_system_version(getOption("rwasm.webr_version"))

  writeLines(sprintf("Processing %d package(s).", nrow(package_info)))

  # Create contrib paths
  contrib_src <- fs::path(repo_dir, "src", "contrib")
  contrib_bin <- fs::path(
    repo_dir, "bin", "emscripten", "contrib",
    paste0(r_version$major, ".", r_version$minor)
  )
  fs::dir_create(contrib_src)
  fs::dir_create(contrib_bin)

  if (fs::is_file(fs::path(contrib_bin, "PACKAGES"))) {
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
    remotes <- system.file("webr-remotes", package = "rwasm") |>
      readLines() |>
      unique()
  }

  # Resolve list of package remotes to prefer
  remotes_deps <- new_pkg_download_proposal(remotes, config = ppm_config)
  remotes_deps <- remotes_deps$resolve()
  remotes_info <- remotes_deps$get_resolution()
  remotes_info <- remotes_info[remotes_info$direct, ]
  remotes_info <- remotes_info[!grepl("/Recommended/", remotes_info$target), ]

  # Prefer package remotes given in remotes list
  remotes_info <- remotes_info |>
    select(.data$package, .data$sources, .data$target, .data$ref, .data$status)
  packages <- package_info |>
    rows_update(remotes_info, by = "package", unmatched = "ignore")

  # Check for any packages not found
  if (any(packages$status == "FAILED")) {
    stop(paste(
      "The following package references cannot be found:",
      paste(packages$ref[packages$status == "FAILED"], collapse = ", ")
    ))
  }

  need_update <- FALSE
  for (n in 1:nrow(packages)) {
    pkg_row <- packages[n, ]
    pkg <- pkg_row$package

    # Get version for this version of the package
    new_ver_string <- pkg_row$version
    new_ver <- as.package_version(new_ver_string)

    # If the package already exists in the given repo
    if (!is.null(repo_info) && pkg %in% repo_packages) {
      # Skip building this package if the versions match
      old_ver <- as.package_version(repo_info[pkg, "Version"])
      if (old_ver == new_ver) {
        next
      }

      #  # Remove the old package from disk
      old_tarball <- paste0(pkg, "_", old_ver, ".tar.gz")
      unlink(fs::path(contrib_src, old_tarball))
      unlink(fs::path(contrib_bin, old_tarball))
    }

    # Download the new package from remote source
    status <- tryCatch(
      {
        if (!fs::file_exists(fs::path("repo", pkg_row$target))) {
          need_update <- TRUE
          make_remote_tarball(
            pkg_row$package,
            pkg_row$sources[[1]][[1]],
            pkg_row$target,
            contrib_src
          )
        }
      },
      error = function(cnd) cnd
    )

    # Skip to next package if source download failed
    if (inherits(status, "error")) {
      warning(status)
      next
    }

    tarball_file <- basename(pkg_row$target)
    tarball_path <- fs::path(contrib_src, tarball_file)

    # Build the package
    status <- tryCatch(
      {
        wasm_build(pkg, tarball_path, contrib_bin)
      },
      error = function(cnd) cnd
    )

    # Skip to next package if building failed
    if (inherits(status, "error")) {
      warning(status)
      next
    }
  }

  # Update the PACKAGES files
  if (need_update) {
    update_packages(contrib_src, contrib_bin)
  }
}

update_packages <- function(contrib_src, contrib_bin) {
  tools::write_PACKAGES(contrib_src, verbose = TRUE)
  tools::write_PACKAGES(contrib_bin, verbose = TRUE, type = "mac.binary")
  invisible(NULL)
}
