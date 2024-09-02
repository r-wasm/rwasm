#' Create an Emscripten metadata file for a given `tar` archive
#'
#' Calculates file offsets and other metadata for content stored in an
#' (optionally gzip compressed) `tar` archive. Together the `tar` archive and
#' resulting metadata file can be mounted as an Emscripten filesystem image,
#' making the content of the archive available to the WebAssembly R process.
#'
#' Outputs a metadata file named by the base name of the `tar` archive with new
#' extension `".js.metadata"`. Both files should be hosted online so that their
#' URL can be provided to webR for mounting on the virtual filesystem.
#'
#' @param file Filename of the `tar` archive to be used as input.
#' @param strip Remove the specified number of leading path elements. Pathnames
#'   with fewer elements are skipped. Defaults to `0`, meaning none.
#' @export
make_tar_index <- function(file, strip = 0) {
  file <- fs::path_norm(file)
  file_ext <- tolower(fs::path_ext(file))
  file_base <- fs::path_ext_remove(file)

  message(paste("Building metadata index for:", file))

  # Check if our tar is compatible
  if (!any(file_ext == c("tgz", "gz", "tar"))) {
    stop(paste0("Can't make index for \"", file,
      "\". Only uncompressed or `gzip` compressed tar files can be indexed."))
  }

  # Handle two-component extensions
  if (file_ext == "gz") {
    file_base <- fs::path_ext_remove(file_base)
  }

  # Should we decompress?
  gzip <- any(file_ext == c("tgz", "gz"))

  # R seems to choke when seeking on a gzfile() connection, so we buffer it
  data <- readBin(file, "raw", n = file.size(file))
  if (gzip) {
    data <- memDecompress(data)
  }
  con <- rawConnection(data, open = "rb")
  on.exit(close(con))

  # Build metadata and write to .js.metadata file
  entries <- read_tar_offsets(con, strip)
  metadata <- list(
    files = entries,
    gzip = gzip,
    ext = gsub(file_base, "", file, ignore.case = TRUE),
    remote_package_size = length(data)
  )
  metadata_file <- paste0(file_base, ".js.metadata")
  jsonlite::write_json(metadata, metadata_file, auto_unbox = TRUE)
}

read_tar_offsets <- function(con, strip) {
  entries <- list()
  next_filename <- NULL

  while (TRUE) {
    # Read tar entry header block
    header <- readBin(con, "raw", n = 512)

    # Empty header indicates end of archive
    if (all(header == 0)) break

    # Entry size and offset
    offset <- seek(con)
    size <- strtoi(sub("\\s.*", "", rawToChar(header[125:136])), 8)
    file_blocks <- ceiling(size / 512)

    # Skip directories, global, and vendor-specific extended headers
    type <- rawToChar(header[157])
    if (grepl("5|g|[A-Z]", type)) {
      next
    }

    # Handle PAX extended header
    if (type == "x") {
      pax_data <- readBin(con, "raw", n = 512 * ceiling(size / 512))
      pax_data <- pax_data[1:max(which(pax_data != as.raw(0x00)))]
      lines <- raw_split(pax_data, "\n")
      for (line in lines) {
        payload <- raw_split(line, " ")[[2]]
        kv <- raw_split(payload, "=")
        if (rawToChar(kv[[1]]) == "path") {
          next_filename <- rawToChar(kv[[2]])
          break
        }
      }
      next
    }

    # Basic tar filename
    filename <- rawToChar(header[1:100])

    # Apply ustar formatted extended filename
    magic <- rawToChar(header[258:263])
    if (magic == "ustar"){
      prefix <- rawToChar(header[346:501])
      filename <- paste(prefix, filename, sep = "/")
    }

    # Apply PAX formatted extended filename
    if (!is.null(next_filename)) {
      filename <- next_filename
      next_filename <- NULL
    }

    # Strip path elements, ignoring leading slash, skip if no path remains
    if (strip > 0) {
      filename <- gsub("^/", "", filename)
      parts <- fs::path_split(filename)[[1]]
      parts <- parts[-strip:-1]
      if (length(parts) == 0) {
        seek(con, 512 * file_blocks, origin = "current")
        next
      }
      filename <- fs::path_join(c("/", parts))
    }

    # Calculate file offsets
    entry <- list(filename = filename, start = offset, end = offset + size)
    entries <- append(entries, list(entry))

    # Skip to next entry header
    seek(con, 512 * file_blocks, origin = "current")
  }
  entries
}

# Split the elements of a raw vector x according to matches of element `split`
raw_split <- function(x, split) {
  if (is.character(split)) {
    split <- charToRaw(split)
  }

  start <- 1
  out <- list()
  for (end in which(x == split)) {
    out <- c(out, list(x[start:(end - 1)]))
    start <- end + 1
  }

  if (start <= length(x)) {
    out <- c(out, list(x[start:length(x)]))
  }

  out
}
