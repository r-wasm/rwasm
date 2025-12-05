# Create an Emscripten filesystem image

Uses Emscripten's `file_packager` tool to build an Emscripten filesystem
image that can be mounted by webR. The filesystem image may contain
arbitrary data that will be made available for use by the WebAssembly R
process once mounted.

## Usage

``` r
file_packager(in_dir, out_dir = "./vfs", out_name = NULL, compress = FALSE)
```

## Arguments

- in_dir:

  Directory to be packaged into the filesystem image.

- out_dir:

  Directory in which to write the output image files. Defaults to
  `"./vfs"`.

- out_name:

  A character string for the output image base filename. If `NULL`,
  defaults to the final component of the input directory path.

- compress:

  Logical. If `TRUE`, a compressed version of the filesystem data is
  included in the output. Defaults to `FALSE`.

## Details

Outputs at least two files (named by `out_name`) in the `out_dir`
directory: a data file with extension `".data"`, and a metadata file
with extension `".js.metadata"`. Both files should be hosted online so
that their URL can be provided to webR for mounting on the Emscripten
virtual filesystem.

When `compress` is `TRUE`, an additional file with extension
`".data.gz"` is also output containing a compressed version of the
filesystem data. The metadata file is also changed to reflect the
availability of a compressed version of the data.
