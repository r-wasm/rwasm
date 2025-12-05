# Technical details for .tar archive metadata

The
[`rwasm::add_tar_index()`](https://r-wasm.github.io/rwasm/reference/add_tar_index.md)
function appends Emscripten filesystem metadata to an (optionally gzip
compressed) `.tar` archive. The resulting output can be directly mounted
by webR to the virtual filesystem, making the content of the archive
available to the WebAssembly R process.

See the [Mounting filesystem
images](https://r-wasm.github.io/rwasm/articles/mount-fs-image.md)
article for more information about mounting filesystem images.

## Filesystem metadata

Virtual filesystem metadata is a JavaScript object, encoded as a JSON
string. The format is defined and output by Emscripten’s `file_packager`
tool and understood by [webR’s mounting
API](https://r-wasm.github.io/rwasm/articles/mount-fs-image.md). The
metadata object gives the location of each file in the archive to be
mounted, and takes the following format:

``` javascript
{
  files: {
    filename: string;
    start: number;
    end: number;
  }[],
};
```

## Archive data layout

A `.tar` archive that can be directly mounted by webR includes
filesystem metadata as a file named `.vfs-index.json` at the top level
of the archive. The `.tar` archive may also include a “metadata hint” at
the very end of the file, after the end-of-archive marker. Appending
additional hint data is optional, but allows for more efficient mounting
of archive contents to the virtual filesystem.

The resulting `.tar` file may be gzip compressed, with file extension
`.tar.gz` or `.tgz`.

| Field | Size     | Description                                                                           |
|-------|----------|---------------------------------------------------------------------------------------|
| 0     | Variable | Standard `.tar` data, including the end-of-archive marker.                            |
| 1     | 4 bytes  | Magic bytes: The string `"webR"`, UTF8 encoded (`0x77656252`).                        |
| 2     | 4 bytes  | Reserved, currently `0x00000000`.                                                     |
| 3     | 4 bytes  | Offset of `.vfs-index.json`, in units of 512-byte blocks. Signed integer, big endian. |
| 4     | 4 bytes  | Length of `.vfs-index.json`, in bytes. Signed integer, big endian.                    |

Data layout for a `.tar` archive containing filesystem metadata.
