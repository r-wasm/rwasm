# Add Emscripten virtual filesystem metadata to a given `tar` archive

Calculates file offsets and other metadata for content stored in an
(optionally gzip compressed) `tar` archive. Once added, the `tar`
archive with metadata can be mounted as an Emscripten filesystem image,
making the contents of the archive available to the WebAssembly R
process.

## Usage

``` r
add_tar_index(file, strip = 0)
```

## Arguments

- file:

  Filename of the `tar` archive for which metadata is to be added.

- strip:

  Remove the specified number of leading path elements when mounting
  with webR. Defaults to `0`.

## Details

The virtual filesystem metadata is appended to the end of the `tar`
archive, with the output replacing the original file. The resulting
archive should be hosted online so that its URL can be provided to webR
for mounting on the virtual filesystem.

If `strip` is greater than `0` the virtual filesystem metadata is
generated such that when mounted by webR the specified number of leading
path elements are removed. Useful for R package binaries where data
files are stored in the original `.tgz` file under a subdirectory. Files
with fewer path name elements than the specified amount are skipped.
