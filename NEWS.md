# rwasm (development version)

# rwasm 0.2.0

## New features

* When building R packages with `compress` set to `TRUE`, use the binary R package `.tgz` file for the Emscripten filesystem image data and generate custom metadata rather than using Emscripten's `file_packager` tool.

* Support for a new `compress` argument in `file_packager()`, `make_vfs_library()`, and other related functions. When enabled, VFS images will be compressed using `gzip` (#39).

Note: Mounting processed `.tgz` archives or compressed VFS images requires at least version 0.4.2 of webR.

# rwasm 0.1.0

## New features

* Added a mechanism to override `AC_CHECK_FUNCS` with Autoconf (#32).

* Shim `uname` and `pkg-config` when cross-compiling (#9).

* Added documentation.

## Breaking changes

* The `dependencies` argument in `add_pkg()` is now `FALSE` by default.

* Made CXX17 the default (#12).

## Bug fixes

* Packages using OpenMP can now be cross-compiled (#17).

* Prevent packages from accessing the host LIBS (#10).

* Use a default shell when running configure scripts (#8).

* Various tweaks and bug fixes for cross-compiling on Linux host.

# rwasm 0.0.1

## Breaking changes

* This R package has been converted from an existing set of R scripts and `Makefile` workflow. Users relying on the old workflow will need to rewrite their processes to work using the new `rwasm` R package.
