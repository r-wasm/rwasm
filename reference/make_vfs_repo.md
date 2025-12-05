# Add Emscripten filesystem images to an R package repository

Creates an Emscripten filesystem image for each R package that exists in
the package repository directory `repo_dir`.

## Usage

``` r
make_vfs_repo(repo_dir = "./repo", compress = FALSE)
```

## Arguments

- repo_dir:

  The package repository directory. Defaults to `"./repo"`.

- compress:

  When `TRUE`, add and compress Emscripten virtual filesystem metadata
  in the resulting R package binary `.tgz` files. Otherwise,
  [`file_packager()`](https://r-wasm.github.io/rwasm/reference/file_packager.md)
  is used to create uncompressed virtual filesystem images included in
  the output binary package repository. Defaults to `TRUE`.

## Details

Each filesystem image is generated using Emscripten's
[`file_packager()`](https://r-wasm.github.io/rwasm/reference/file_packager.md)
tool and the output `.data` and `.js.metadata` filesystem image files
are written to the repository in the same directory as the package
binary `.tgz` files.

The resulting filesystem images may then be used by webR to download and
install R packages by mounting the `.data` images to the Emscripten
virtual filesystem.

When `compress` is `TRUE`, an additional file with extension
`".data.gz"` is also output containing a compressed version of the
filesystem data.
