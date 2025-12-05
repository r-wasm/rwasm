# Mounting filesystem images

The Emscripten WebAssembly (Wasm) environment provides a virtual
filesystem (VFS) which supports the concept of *mounting*. With this, an
entire file and directory structure can be packaged into a filesystem
image, efficiently making individual files or entire R package libraries
available for use in webR.

## Create filesystem images

### Emscripten’s `file_packager` tool

The
[`file_packager`](https://emscripten.org/docs/porting/files/packaging_files.html#packaging-using-the-file-packager-tool)
tool, provided by Emscripten, takes in a directory structure as input
and produces a webR compatible filesystem image as output. The
[`file_packager`](https://emscripten.org/docs/porting/files/packaging_files.html#packaging-using-the-file-packager-tool)
tool may be invoked from the [rwasm](https://r-wasm.github.io/rwasm/)
package:

``` r
rwasm::file_packager("./input", out_dir = ".", out_name = "output")
```

It can also be invoked directly using its CLI[¹](#fn1), if you prefer:

``` bash
$ file_packager output.data --preload ./input@/ \
    --separate-metadata --js-output=output.js
```

In the above examples, the files in the directory `./input` are packaged
and an output filesystem image is created[²](#fn2) consisting of a data
file, `output.data`, and a metadata file, `output.js.metadata`.

To prepare for mounting the filesystem image with webR, ensure that both
files have the same basename (in this example, `output`). The resulting
URLs or relative paths for the two files should differ only by the file
extension.

#### Compression

Filesystem image `.data` files may optionally be `gzip` compressed prior
to deployment. The file extension for compressed filesystem images
should be `.data.gz`, and compression should be indicated by setting the
property `gzip: true` on the metadata JSON stored in the `.js.metadata`
file.

**NOTE**: Loading compressed VFS images requires at least version 0.4.1
of webR.

### Mount `.tar` archives as a filesystem image

Archives in `.tar` format, optionally gzip compressed as `.tar.gz` or
`.tgz` files, can also be used as filesystem images by pre-processing
the `.tar` archive using the
[`rwasm::add_tar_index()`](https://r-wasm.github.io/rwasm/reference/add_tar_index.md)
function. The function reads archive contents and appends the required
filesystem metadata to the end of the `.tar` archive data in a way that
is understood by webR. For further information about the format see the
[Technical details for .tar archive
metadata](https://r-wasm.github.io/rwasm/articles/tar-metadata.md)
article.

``` r
rwasm::add_tar_index("./path/to/archive.tar.gz")
# Appending virtual filesystem metadata for: ./path/to/archive.tar.gz
```

Once processed by
[`rwasm::add_tar_index()`](https://r-wasm.github.io/rwasm/reference/add_tar_index.md),
the `.tar` archive can be deployed and used directly as a filesystem
image.

## Mounting filesystem images

When running in a web browser, the
[`webr::mount()`](https://docs.r-wasm.org/webr/latest/api/r.html#mount)
function downloads and mounts a filesystem image from a URL source,
using the `WORKERFS` filesystem type.

``` r
webr::mount(
  mountpoint = "/data",
  source = "https://example.com/output.data"
)
```

Filesystem images should be deployed to static file hosting[³](#fn3) and
the resulting URL provided as the source argument. The image will be
mounted in the virtual filesystem under the path given by the
`mountpoint` argument. If the `mountpoint` directory does not exist, it
will be created prior to mounting.

When running under Node.js, the source may also be provided as a
relative path to a filesystem image on disk.

To test filesystem images before deployment, serve them using a local
static webserver. See the Local Testing section below for an example
using `httpuv::runStaticServer()` in R.

## Building an R package library image

A collection of R packages can be collected and bundled into a single
filesystem image for mounting.

To build an R package library image we must first build one or more Wasm
R packages using
[`add_pkg()`](https://r-wasm.github.io/rwasm/reference/add_pkg.md). As
an example, let’s build a package with a few hard dependencies. Ensure
that you are running R in an environment with access to Wasm development
tools[⁴](#fn4), then run:

``` r
rwasm::add_pkg("dplyr")
```

After the build process has completed, the new `repo` directory contains
a CRAN-like package repository with R packages build for Wasm.

Next, run the following to build an Emscripten VFS image:

``` r
rwasm::make_vfs_library()
```

By default, this function will create a new directory named `vfs` if it
does not exist. The files `vfs/library.data` and
`vfs/library.js.metadata` together form an Emscripten filesystem image
containing an R package library consisting of all the packages
previously added to the CRAN-like repository in `repo` using
[`add_pkg()`](https://r-wasm.github.io/rwasm/reference/add_pkg.md).

### Local testing

The following R command starts a local web server to serve your
filesystem image for testing[⁵](#fn5). When serving your files locally,
be sure to include the `Access-Control-Allow-Origin: *` HTTP header,
required for downloading files from a cross-origin server by the
[CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
mechanism.

``` r
httpuv::runStaticServer(
  dir = ".",
  port = 9090,
  browse = FALSE,
  headers = list("Access-Control-Allow-Origin" =  "*")
)
```

Once the web server is running start a webR session in your browser,
such as the console at <https://webr.r-wasm.org/latest/>. Use
`webr::mount()` to make the R library image available somewhere on the
VFS[⁶](#fn6):

``` r
webr::mount("/my-library", "http://127.0.0.1:9090/vfs/library.data")
```

Once mounted, the contents of the filesystem image are available at
`/my-library` in the virtual filesystem.

``` r
list.files("/my-library")
#>  [1] "R6"         "cli"        "dplyr"     "fansi"      "generics"   "glue"
#>  [7] "lifecycle"  "magrittr"   "pillar"    "pkgconfig"  "rlang"      "tibble"
#> [13] "tidyselect" "utf8"       "vctrs"     "withr"
```

This new directory should be added to R’s
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html), so that R
packages may be loaded from the new library.

``` r
.libPaths(c(.libPaths(), "/my-library"))
library(dplyr)
#> Attaching package: ‘dplyr’
#>
#> The following objects are masked from ‘package:stats’:
#>
#>     filter, lag
#>
#> The following objects are masked from ‘package:base’:
#>
#>     intersect, setdiff, setequal, union
```

------------------------------------------------------------------------

1.  See the
    [`file_packager`](https://emscripten.org/docs/porting/files/packaging_files.html#packaging-using-the-file-packager-tool)
    Emscripten documentation for details.

2.  When using the `file_packager` CLI, a third file named `output.js`
    will also be created. If you only plan to mount the image using
    webR, this file may be discarded.

3.  e.g. GitHub Pages, Netlify, AWS S3, etc.

4.  See the “Setting up the WebAssembly toolchain” section in
    [`vignette("rwasm")`](https://r-wasm.github.io/rwasm/articles/rwasm.md)
    for further details.

5.  Ensure that the latest version of the `httpuv` package is installed
    so that the `?httpuv::runStaticServer` function is available.

6.  You might need to adjust the path portion of the URL, depending on
    your set-up. If it does not work, you could also try
    `"http://127.0.0.1:9090"` or `"http://127.0.0.1:9090/output/vfs"`
