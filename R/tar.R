#' Add Emscripten virtual filesystem metadata to a given `tar` archive
#'
#' Calculates file offsets and other metadata for content stored in an
#' (optionally gzip compressed) `tar` archive. Once added, the `tar` archive
#' with metadata can be mounted as an Emscripten filesystem image, making the
#' contents of the archive available to the WebAssembly R process.
#'
#' The virtual filesystem metadata is appended to the end of the `tar` archive,
#' with the output replacing the original file. The resulting archive should be
#' hosted online so that its URL can be provided to webR for mounting on the
#' virtual filesystem.
#'
#' If `strip` is greater than `0` the virtual filesystem metadata is generated
#' such that when mounted by webR the specified number of leading path elements
#' are removed. Useful for R package binaries where data files are stored in the
#' original `.tgz` file under a subdirectory. Files with fewer path name
#' elements than the specified amount are skipped.
#'
#' @param file Filename of the `tar` archive for which metadata is to be added.
#' @param strip Remove the specified number of leading path elements when
#'   mounting with webR. Defaults to `0`.
#' @export
add_tar_index <- function(file, strip = 0) {
  file <- fs::path_norm(file)
  file_ext <- tolower(fs::path_ext(file))
  file_base <- fs::path_ext_remove(file)

  message(paste("Appending virtual filesystem metadata for:", file))

  # Check if our tar is compatible
  if (!any(file_ext == c("tgz", "gz", "tar"))) {
    stop(paste0("Can't make index for \"", file,
      "\". Only uncompressed or `gzip` compressed tar files can be indexed."))
  }

  # Handle two-component extensions
  if (file_ext == "gz") {
    file_base <- fs::path_ext_remove(file_base)
  }

  # Read archive contents, decompressing if necessary
  gzip <- any(file_ext == c("tgz", "gz"))
  data <- readBin(file, "raw", n = file.size(file))
  if (gzip) {
    data <- memDecompress(data)
  }

  # Build metadata from source .tar file
  con <- rawConnection(data, open = "rb")
  on.exit(close(con), add = TRUE)
  entries <- read_tar_offsets(con, strip)
  tar_end <- seek(con)

  metadata <- list(
    files = entries,
    gzip = gzip,
    remote_package_size = length(data)
  )

  # Add metadata as additional .tar entry
  entry <- create_metadata_entry(metadata)
  json_block <- as.integer(tar_end / 512) + 1L

  # Append additional metadata hint for webR
  magic <- charToRaw('webR')
  reserved <- raw(4) # reserved for future use
  block <- writeBin(json_block, raw(), size = 4, endian = "big")
  len <- writeBin(entry$length, raw(), size = 4, endian = "big")
  hint <- c(magic, reserved, block, len)

  # Build new .tar archive data
  data <- c(data[1:tar_end], entry$data, raw(1024), hint)

  # Write output and move into place
  out <- tempfile()
  out_con <- if (gzip) {
    gzfile(out, open = "wb")
  } else {
    file(out, open = "wb")
  }
  writeBin(data, out_con, size = 1L)
  close(out_con)
  fs::file_copy(out, file, overwrite = TRUE)
}

create_metadata_entry <- function(metadata) {
  # metadata contents
  json <- charToRaw(jsonlite::toJSON(metadata, auto_unbox = TRUE))
  len <- length(json)
  blocks <- ceiling(len/512)
  length(json) <- 512 * blocks

  # entry header
  timestamp <- as.integer(Sys.time())
  header <- raw(512)
  header[1:15] <- charToRaw('.vfs-index.json')               # filename
  header[101:108] <- charToRaw('0000644 ')                   # mode
  header[109:116] <- charToRaw('0000000 ')                   # uid
  header[117:124] <- charToRaw('0000000 ')                   # gid
  header[125:136] <- charToRaw(sprintf("%011o ", len))       # length
  header[137:148] <- charToRaw(sprintf("%011o ", timestamp)) # timestamp
  header[149:156] <- charToRaw('        ')                   # placeholder
  header[157:157] <- charToRaw('0')                          # type
  header[258:262] <- charToRaw('ustar')                      # ustar magic
  header[264:265] <- charToRaw('00')                         # ustar version
  header[266:269] <- charToRaw('root')                       # user
  header[298:302] <- charToRaw('wheel')                      # group

  # populate checksum field
  checksum <- raw(8)
  checksum[1:6] <- charToRaw(sprintf("%06o", sum(as.integer(header))))
  checksum[8] <- charToRaw(' ')
  header[149:156] <- checksum

  list(data = c(header, json), length = len)
}

read_tar_offsets <- function(con, strip) {
  entries <- list()
  next_filename <- NULL

  while (TRUE) {
    # Read tar entry header block
    header <- readBin(con, "raw", n = 512)

    # Empty header indicates end of archive
    if (all(header == 0)) {
      # Return connection position to just before this header
      seek(con, -512, origin = "current")
      break
    }

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
