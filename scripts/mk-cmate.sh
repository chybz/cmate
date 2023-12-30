#!/usr/bin/env bash

MY_DIR=$(dirname "${BASH_SOURCE[0]}")
MY_DIR=$(realpath "$MY_DIR"/..)
LIB_DIR=$MY_DIR/lib/cmake
CMATE=$MY_DIR/bin/cmate

while read -r INC; do
    MOD=${INC#include(}
    MOD=${MOD%)}
    echo "MODULE: ${MOD}"
done <<< $(grep 'include' $CMATE)
