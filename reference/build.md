# Build one or more R packages for WebAssembly

Downloads and builds the [R package
references](https://r-lib.github.io/pkgdepends/reference/pkg_refs.html)
given by `packages`, compiling each package for use with WebAssembly and
webR. The resulting WebAssembly binary packages are written to
`out_dir`.

## Usage

``` r
build(
  packages,
  out_dir = ".",
  remotes = NULL,
  dependencies = FALSE,
  compress = TRUE
)
```

## Arguments

- packages:

  A character vector of one or more package references.

- out_dir:

  The output directory. Defaults to `"."`.

- remotes:

  A character vector of package references to prefer as a remote source.
  If `NA`, use a built-in list of references to packages pre-modified
  for use with webR. Defaults to `NULL`, meaning no preference over the
  usual remote sources.

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
