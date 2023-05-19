#!/bin/bash
set -eu

[[ -z "${1-}" ]] && echo "Error: Must supply tarball" && exit 1
[[ ! -f "$1" ]] && echo "Error: Must supply a tarball file" && exit 1

PKG_NAME=$(basename $1)
[[ $PKG_NAME =~ ([^_]+)_ ]]
PKG_NAME="${BASH_REMATCH[1]-NULL}"

[[ "$PKG_NAME" == "NULL" ]] && echo "Error: File does not conform to a versioned tarball" && exit 1

ROOT=$(dirname $(realpath "$0"))
ORIG=$(realpath .)
TMP=$(mktemp -d)
TARBALL=$(realpath "$1")

export R_MAKEVARS_USER="${ROOT}/webr-vars.mk"

cd $TMP
tar xvf $TARBALL

# Need to use an empty library and only then copy to the `lib` folder,
# otherwise R might try to load wasm packages from the library and fail
mkdir lib

$R_HOST/bin/R CMD INSTALL --build --library="lib" "${PKG_NAME}" \
  --no-docs \
  --no-test-load \
  --no-staged-install \
  --no-byte-compile

if [ -d "${ROOT}/lib/${PKG_NAME}" ]; then
  rm -rf "${ROOT}/lib/${PKG_NAME}"
fi
mv lib/* ${ROOT}/lib

BIN="${ORIG}/repo/bin/emscripten/contrib/${R_VERSION}/"

mkdir -p $BIN
find . -name '*.tgz' -exec mv {} $BIN \;
find . -name '*.tar.gz' -exec sh -c \
  'f="{}"; v="${f#*_}"; mv -- "$f" "'${BIN}'${f%%_*}_${v%%_*}.tgz"' \;

cd ${ORIG}
rm -rf ${TMP}
