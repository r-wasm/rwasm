# Mounting host directories in node

## Introduction

When running under Node.js, the Emscripten WebAssembly environment can
make available the contents of a directory on the host filesystem. In
addition to providing webR access to external data files, a pre-prepared
R package library can be mounted from the host filesystem. This avoids
the need to download potentially large R packages or filesystem images
over the network.

See the [webR documentation for more
details](https://docs.r-wasm.org/webr/latest/mounting.html#mount-an-existing-host-directory)
on mounting host directories under Node.js.

## Building an R package library

To build an R package library, we must first build one or more Wasm R
packages using
[`add_pkg()`](https://r-wasm.github.io/rwasm/reference/add_pkg.md). As
an example, let’s build a package with a few hard dependencies. Ensure
that you are running R in an environment with access to Wasm development
tools[¹](#fn1), then run:

``` r
rwasm::add_pkg("dplyr")
```

After the build process has completed, the new `repo` directory contains
a CRAN-like package repository with R packages build for Wasm.

Next, run the following to build an R package library:

``` r
rwasm::make_library()
```

By default, this function will create a new directory named `lib` if it
does not already exist. This directory will contain an R package library
consisting of all the packages previously added to the CRAN-like
repository in `repo` using
[`add_pkg()`](https://r-wasm.github.io/rwasm/reference/add_pkg.md).

## Mounting host directories

In your node application, use the webR JS API to create a new directory
on the VFS and mount the host directory containing your R packages:

``` js
await webR.init();
await webR.FS.mkdir("/my-library");
await webR.FS.mount('NODEFS', { root: '/path/to/lib' }, "/my-library");
```

Once mounted, the contents of your host R library directory are
available at `/my-library` in the virtual filesystem.

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

1.  See the “Setting up the WebAssembly toolchain” section in
    [`vignette("rwasm")`](https://r-wasm.github.io/rwasm/articles/rwasm.md)
    for further details.
