find_webr <- function() {
  webr_root <- Sys.getenv("WEBR_ROOT")
  if (webr_root != "" && fs::dir_exists(webr_root)) {
    return(webr_root)
  }
  webr_config <- fs::path_expand("~/.webr-vars.mk")
  if (fs::is_file(webr_config)) {
    for (entry in strsplit(readLines(webr_config), split = "=")) {
      if (entry[1] == "WEBR_ROOT") {
        return(entry[2])
      }
    }
  }
  warning("Unable to find webR root directory.")
  NULL
}

find_emscripten <- function() {
  emsdk_env <- Sys.getenv("EMSDK")
  if (emsdk_env != "" && fs::dir_exists(emsdk_env)) {
    return(fs::path(emsdk_env, "upstream", "emscripten"))
  }

  emscripten_env <- Sys.getenv("EMSCRIPTEN_ROOT")
  if (emscripten_env != "" && fs::dir_exists(emscripten_env)) {
    return(emscripten_env)
  }

  webr_config <- fs::path_expand("~/.webr-vars.mk")
  if (fs::is_file(webr_config)) {
    for (entry in strsplit(readLines(webr_config), split = "=")) {
      if (entry[1] == "EMSDK") {
        return(fs::path(entry[2], "upstream", "emscripten"))
      } else if (entry[1] == "EMSCRIPTEN_ROOT") {
        return(entry[2])
      }
    }
  }
  warning("Unable to find Emscripten root directory.")
  NULL
}

.onLoad <- function(libname, pkgname) {
  webr_root <- find_webr()
  emscripten_root <- find_emscripten()
  webr_version <- readLines(fs::path(webr_root, "R", "R-VERSION"))
  options(rwasm.webr_root = webr_root)
  options(rwasm.webr_version = webr_version)
  options(rwasm.emscripten_root = emscripten_root)
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    paste("Targeting Wasm packages for R", options("rwasm.webr_version"))
  )
  packageStartupMessage(
    paste("With `WEBR_ROOT` directory:", options("rwasm.webr_root"))
  )
  packageStartupMessage(
    paste("With `EMSCRIPTEN_ROOT` directory:", options("rwasm.emscripten_root"))
  )
}
