#!/usr/bin/env bash

MY_DIR=$(dirname "${BASH_SOURCE[0]}")
MY_DIR=$(realpath "$MY_DIR"/..)
LIB_DIR=$MY_DIR/lib
TMPL_DIR=$MY_DIR/templates
CMATE=$MY_DIR/bin/cmate
IN_INC_BLOCK=0

#
# Main script and "includes"
#
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
    elif [[ "$LINE" == "## CMATE TEMPLATES" ]]; then
        TMPLS=$(cd $TMPL_DIR && find . -type f | sed -e 's,^./,,g' | xargs)

        for T in ${TMPLS}; do
            TVAR=${T^^}
            TVAR=${TVAR//-/_}
            TVAR=${TVAR////_}
            TVAR=${TVAR//./_}

            cat <<_EOF_TMPL_

###############################################################################
#
# Template ${TVAR}
#
###############################################################################
set(
    CMATE_${TVAR}
    [=[
_EOF_TMPL_

            egrep \
                -v '^# -[*]-' \
                "${TMPL_DIR}/${T}"

            echo "]=])"
        done
    elif ((!IN_INC_BLOCK)); then
        echo "$LINE"
    fi
done < "$CMATE"
