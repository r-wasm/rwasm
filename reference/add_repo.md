# Add all packages from a CRAN-like repository to a package repository

Downloads and builds all available source R packages from the R package
repositories given by `repos`, compiling each package for use with
WebAssembly and webR. The resulting WebAssembly binary packages are
added to the repository directory `repo_dir`. The repository directory
will be created if it does not already exist.

## Usage

``` r
add_repo(repos = ppm_config$cran_mirror, skip = FALSE, ...)
```

## Arguments

- repos:

  A character vector containing the base URL(s) of CRAN-like R package
  repositories. Defaults to the Posit Package Manager CRAN mirror.

- skip:

  A character string containing a regular expression matching names of
  packages to skip. Defaults to `FALSE`, meaning keep all packages.

- ...:

  Arguments passed on to
  [`add_pkg`](https://r-wasm.github.io/rwasm/reference/add_pkg.md)

  `repo_dir`

  :   The package repository directory. Defaults to `"./repo"`.

  `remotes`

  :   A character vector of package references to prefer as a remote
      source. Defaults to `NA`, meaning prefer a built-in list of
      references to packages pre-modified for use with webR.

  `dependencies`

  :   Dependency specification for packages to additionally add to the
      repository. Defaults to `FALSE`, meaning no additional packages.
      Use `NA` to install only hard dependencies whereas `TRUE` installs
      all optional dependencies as well. See
      [pkgdepends::as_pkg_dependencies](https://r-lib.github.io/pkgdepends/reference/as_pkg_dependencies.html)
      for details.

  `compress`

  :   When `TRUE`, add and compress Emscripten virtual filesystem
      metadata in the resulting R package binary `.tgz` files.
      Otherwise,
      [`file_packager()`](https://r-wasm.github.io/rwasm/reference/file_packager.md)
      is used to create uncompressed virtual filesystem images included
      in the output binary package repository. Defaults to `TRUE`.
