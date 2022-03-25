#!/bin/bash
set -eu

[[ -z "${1-}" ]] && echo "Error: Must supply tarball" && exit 1
[[ ! -f "$1" ]] && echo "Error: Must supply a tarball file" && exit 1

[[ $1 =~ /([^/]+)_[-0-9\.]*\.tar\.gz ]]
PKG_NAME="${BASH_REMATCH[1]-NULL}"

[[ "$PKG_NAME" == "NULL" ]] && echo "Error: File does not conform to a versioned tarball" && exit 1

ROOT=$(dirname $(realpath "$0"))
ORIG=$(realpath .)
TMP=$(mktemp -d)
TARBALL=$(realpath "$1")

export R_MAKEVARS_USER="${ROOT}/webr-vars.mk"

cd $TMP
tar xvf $TARBALL
mkdir lib

R CMD INSTALL --build --library="lib" "${PKG_NAME}" \
  --no-docs \
  --no-test-load \
  --no-staged-install \
  --no-byte-compile

BIN="${ORIG}/repo/bin/emscripten/contrib/${R_VERSION}/"

mkdir -p $BIN
mv *.tgz $BIN

cd ${ORIG}
rm -rf ${TMP}
