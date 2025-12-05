# Create an Emscripten filesystem image of an R package library

Extracts all binary R packages contained in the repository directory
`repo_dir` and creates an Emscripten filesystem image containing the
resulting package library.

## Usage

``` r
make_vfs_library(
  out_dir = "./vfs",
  out_name = "library.data",
  repo_dir = "./repo",
  compress = FALSE,
  ...
)
```

## Arguments

- out_dir:

  Directory in which to write the output image files. Defaults to
  `"./vfs"`.

- out_name:

  A character string for the output library image filename.

- repo_dir:

  The package repository directory. Defaults to `"./repo"`.

- compress:

  When `TRUE`, add and compress Emscripten virtual filesystem metadata
  in the resulting R package binary `.tgz` files. Otherwise,
  [`file_packager()`](https://r-wasm.github.io/rwasm/reference/file_packager.md)
  is used to create uncompressed virtual filesystem images included in
  the output binary package repository. Defaults to `TRUE`.

- ...:

  Arguments passed on to
  [`make_library`](https://r-wasm.github.io/rwasm/reference/make_library.md)

  `strip`

  :   A character vector of directories to strip from each R package.

## Details

A single filesystem image is generated using Emscripten's
[`file_packager()`](https://r-wasm.github.io/rwasm/reference/file_packager.md)
tool and the output `.data` and `.js.metadata` filesystem image files
are written to the directory `out_dir`.

When `compress` is `TRUE`, an additional file with extension
`".data.gz"` is also output containing a compressed version of the
filesystem data.

The resulting image can be downloaded by webR and mounted on the
Emscripten virtual filesystem as an efficient way to provide a
pre-configured R library, without installing each R package
individually.
