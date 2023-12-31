#!/usr/bin/env bash

MY_DIR=$(dirname "${BASH_SOURCE[0]}")
MY_DIR=$(realpath "$MY_DIR"/..)
LIB_DIR=$MY_DIR/lib
CMATE=$MY_DIR/bin/cmate
IN_INC_BLOCK=0

while IFS= read -r LINE; do
    if [[ "$LINE" == "## BEGIN CMATE INCLUDES" ]]; then
        IN_INC_BLOCK=1
    elif [[ "$LINE" == "## END CMATE INCLUDES" ]]; then
        IN_INC_BLOCK=0
    elif [[ \
        $IN_INC_BLOCK \
        && \
        "$LINE" =~ ^[[:space:]]*include\((.+)\).*$ \
    ]]; then
        INC="${BASH_REMATCH[1]}.cmake"
        cat <<_EOF_INC_
###############################################################################
#
# Content of ${INC}
#
###############################################################################
_EOF_INC_
        cat "$LIB_DIR"/"$INC"
    elif ((!IN_INC_BLOCK)); then
        echo "$LINE"
    fi
done < "$CMATE"

