# Add R package reference(s) to a package repository

Downloads and builds the [R package
references](https://r-lib.github.io/pkgdepends/reference/pkg_refs.html)
given by `packages`, compiling each package for use with WebAssembly and
webR. The resulting WebAssembly binary packages are added to the
repository directory `repo_dir`. The repository directory will be
created if it does not already exist.

## Usage

``` r
add_pkg(
  packages,
  repo_dir = "./repo",
  remotes = NA,
  dependencies = FALSE,
  compress = TRUE
)
```

## Arguments

- packages:

  A character vector of one or more package references.

- repo_dir:

  The package repository directory. Defaults to `"./repo"`.

- remotes:

  A character vector of package references to prefer as a remote source.
  Defaults to `NA`, meaning prefer a built-in list of references to
  packages pre-modified for use with webR.

- dependencies:

  Dependency specification for packages to additionally add to the
  repository. Defaults to `FALSE`, meaning no additional packages. Use
  `NA` to install only hard dependencies whereas `TRUE` installs all
  optional dependencies as well. See
  [pkgdepends::as_pkg_dependencies](https://r-lib.github.io/pkgdepends/reference/as_pkg_dependencies.html)
  for details.

- compress:

  When `TRUE`, add and compress Emscripten virtual filesystem metadata
  in the resulting R package binary `.tgz` files. Otherwise,
  [`file_packager()`](https://r-wasm.github.io/rwasm/reference/file_packager.md)
  is used to create uncompressed virtual filesystem images included in
  the output binary package repository. Defaults to `TRUE`.
