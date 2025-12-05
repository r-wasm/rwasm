# Create an R package library

Extracts all R packages contained in the repository directory `repo_dir`
and writes them to a library directory `lib_dir`.

## Usage

``` r
make_library(repo_dir = "./repo", lib_dir = "./lib", strip = NULL)
```

## Arguments

- repo_dir:

  The package repository directory. Defaults to `"./repo"`.

- lib_dir:

  Package library output directory. Defaults to `"./lib"`.

- strip:

  A character vector of directories to strip from each R package.

## Details

The `lib_dir` directory will be created if it does not already exist.

The `strip` argument may be used to strip certain directories from
packages installed to the library directory `lib_dir`. This can be used
to reduce the total library file size by removing directories that are
not strictly necessary for the R package to run, such as directories
containing documentation and vignettes.
