#!/usr/bin/env bash

set -e -o pipefail

ME=$(basename "${BASH_SOURCE[0]}")
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
MY_DIR=$(realpath "$MY_DIR"/..)
BIN_DIR=$MY_DIR/bin
SCRIPTS_DIR=$MY_DIR/scripts
REL_DIR=$MY_DIR/releases
STAGE_DIR="$REL_DIR/stage"
VERSION_FILE=$MY_DIR/VERSION

[ -z "$1" ] && echo "$ME: missing version" && exit 1

VERSION="$1"

# Update changelog
echo "$VERSION" > "$VERSION_FILE"

# Update version in main script
sed \
   -i "" \
   -e "s/^set(CMATE_VER.*/set(CMATE_VER \"$VERSION\")/" \
   "$BIN_DIR/cmate"

# Prepare releases directory
rm -rf "$REL_DIR"
mkdir -p "$REL_DIR"
mkdir -p "$REL_DIR/stage"

# Build amalgamated CMate script
$SCRIPTS_DIR/amalgamate.sh > "$STAGE_DIR/cmate"
chmod +x "$STAGE_DIR/cmate"

# Make release archive
cd $STAGE_DIR

zip \
    -rm \
    "$REL_DIR/cmate-$VERSION.zip" \
    cmate
