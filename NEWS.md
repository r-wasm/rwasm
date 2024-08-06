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
