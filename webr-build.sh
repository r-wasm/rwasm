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

R CMD INSTALL --build --library="${ROOT}/lib" "${PKG_NAME}" \
  --no-docs \
  --no-test-load \
  --no-staged-install \
  --no-byte-compile

BIN="${ORIG}/repo/bin/emscripten/contrib/${R_VERSION}/"

mkdir -p $BIN
mv *.tgz $BIN

cd ${ORIG}
rm -rf ${TMP}
