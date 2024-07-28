function(cmate_yaml_load2 FILE VAR)
endfunction()



###############################################################################
#
# Simple YAML parser based on YAML::Tiny
#
###############################################################################
function(cmate_yaml_type PATH VAR)
    set(RES "UNKNOWN")

    foreach(TYPE "scalar" "array" "hash")
        if("${PATH}.__type__" STREQUAL "${TYPE}")
            string(TOUPPER ${TYPE} RES)
            break()
        endif()
    endforeach()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_yaml_check_type PATH TYPE)
    cmate_yaml_type(${PATH} T)

    if(NOT "${T}" STREQUAL "${TYPE}")
        cmate_die("invalid type for ${PATH}: expected ${TYPE}, got ${T}")
    endif()
endfunction()

function(cmate_yaml_is_subkey STR VAR)
    set(RES 0)

    if(STR MATCHES "^__[0-9]+$")
        set(RES 1)
    endif()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_yaml_keys PATH VAR)
    set(${VAR} "${${PATH}.__keys__}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_load FILE VAR)
    set(LINES "")

    if(EXISTS ${FILE})
        file(STRINGS ${FILE} FLINES)
    endif()

    foreach(LINE ${FLINES})
        if(LINE MATCHES "^[ ]*(#.*)?$")
            # Strip comments
            continue()
        else()
            list(APPEND LINES "${LINE}")
        endif()
    endforeach()

    list(LENGTH LINES PREV_LINE_COUNT)

    while(LINES)
        list(GET LINES 0 LINE)

        if(LINE STREQUAL "---")
            # A document (ignored)
            list(POP_FRONT LINES)
        elseif(LINE MATCHES "^[ ]*-([ ]|$|-+$)")
            cmate_yaml_load_array("0" "${LINES}" LINES JSON)
        elseif(LINE MATCHES "^([ ]*)[^ ]")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            cmate_yaml_load_hash("${LEN}" "${LINES}" LINES JSON)
        endif()

        list(LENGTH LINES LINE_COUNT)

        if(NOT ${LINE_COUNT} LESS ${PREV_LINE_COUNT})
            cmate_die("cmate_yaml_load: no lines consumed")
        endif()
    endwhile()

    set(${VAR} "${JSON}" PARENT_SCOPE)
endfunction()

#
# Implementation
#
macro(cmate_yaml_set JSON KEY VAL)
    list(APPEND CMATE_YAML__VARS "${VAR}")

    if(${VAR})
        set(VAL "${${VAR}};${VAL}")
    endif()

    set(${VAR} "${VAL}")
endmacro()

macro(cmate_yaml_set_type VAR TYPE)
    unset(${VAR})
    cmate_yaml_set("${VAR}.__type__" "${TYPE}")
endmacro()

function(cmate_yaml_load_scalar STR VAR)
    set(VALUE "")
    set(IS_KEY 0)

    if(${ARGC} GREATER 2 AND ARGV2 STREQUAL "1")
        set(IS_KEY 1)
    endif()

    # Trim whitespace and comments
    string(REGEX REPLACE "^[ ]+" "" STR ${STR})
    string(REGEX REPLACE "[ ]+$" "" STR ${STR})
    string(REGEX REPLACE "#.*$" "" STR ${STR})

    if("${STR}" STREQUAL "~")
        set(VALUE "null")
    else()
        cmate_unquote(${STR} VALUE)

        if(VALUE MATCHES "[^0-9]" AND NOT ${IS_KEY})
            set(VALUE "\"${VALUE}\"")
        endif()
    endif()

    set(${VAR} "${VALUE}" PARENT_SCOPE)
endfunction()

macro(cmate_check_indent INDENTS LINE)
    if("${LINE}" MATCHES "^([ ]*)")
        string(LENGTH "${CMAKE_MATCH_1}" LEN)
        list(GET INDENTS -1 INDENT)

        if(${LEN} LESS ${INDENT})
            break()
        elseif(${LEN} GREATER ${INDENT})
            cmate_die("bad indenting: (${LEN} > ${INDENT}): '${LINE}'")
        endif()
    else()
        # Should not happen
        cmate_die("invalid array line: ${LINE}")
    endif()
endmacro()

function(cmate_yaml_load_array INDENTS LINES LINES_VAR JSON_VAR)
    set(ARRAY "[]")

    while(LINES)
        list(GET LINES 0 LINE)

        cmate_check_indent("${INDENTS}" "${LINE}")

        if(${LINE} MATCHES "^([ ]*-[ ]+)[^\\'\"][^ ]*[ ]*:([ ]+|$)")
            # Inline nested hash
            string(LENGTH "${CMAKE_MATCH_1}" INDENT2)

            string(REPLACE "-" " " LINE "${LINE}")
            list(POP_FRONT LINES)
            list(PREPEND LINES "${LINE}")

            cmate_yaml_load_hash(
                "${INDENTS};${INDENT2}"
                "${LINES}"
                LINES
                OBJ
            )

            string(JSON POS LENGTH "${ARRAY}")
            string(JSON ARRAY SET ${ARRAY} ${POS} ${OBJ})
        elseif(${LINE} MATCHES "^[ ]*-([ ]*)(.+)[ ]*$")
            # Array entry with value
            list(POP_FRONT LINES)
            cmate_yaml_load_scalar("${CMAKE_MATCH_2}" VALUE)

            string(JSON POS LENGTH "${ARRAY}")
            string(JSON ARRAY SET ${ARRAY} ${POS} ${VALUE})
        endif()
    endwhile()

    set(${LINES_VAR} ${LINES} PARENT_SCOPE)
    set(${JSON_VAR} ${ARRAY} PARENT_SCOPE)
endfunction()

function(cmate_yaml_load_hash INDENTS LINES LINES_VAR JSON_VAR)
    set(HASH "{}")

    while(LINES)
        list(GET LINES 0 LINE)

        cmate_check_indent("${INDENTS}" "${LINE}")

        if(${LINE} MATCHES "^([ ]*(.+):)")
            string(LENGTH "${CMAKE_MATCH_1}" TOSTRIP)
            cmate_yaml_load_scalar("${CMAKE_MATCH_2}" KEY 1)
            string(SUBSTRING ${LINE} ${TOSTRIP} -1 LINE)
        endif()

        if(NOT "${LINE}" STREQUAL "")
            # We have a value
            cmate_yaml_load_scalar("${LINE}" VALUE)
            string(JSON HASH SET ${HASH} ${KEY} ${VALUE})
            list(POP_FRONT LINES)
        else()
            # Indent/sub hash
            list(POP_FRONT LINES)

            if(NOT LINES)
                string(JSON HASH SET ${HASH} ${KEY} "null")
                break()
            endif()

            list(GET LINES 0 LINE)

            if(${LINE} MATCHES "^([ ]*)-")
                string(LENGTH "${CMAKE_MATCH_1}" LEN)
                cmate_yaml_load_array(
                    "${INDENTS};${LEN}"
                    "${LINES}"
                    LINES
                    OBJ
                )
                string(JSON HASH SET ${HASH} ${KEY} ${OBJ})
            elseif(${LINE} MATCHES "^([ ]*).")
                string(LENGTH "${CMAKE_MATCH_1}" LEN)
                cmate_yaml_load_hash(
                    "${INDENTS};${LEN}"
                    "${LINES}"
                    LINES
                    OBJ
                )
                string(JSON HASH SET ${HASH} ${KEY} ${OBJ})
            endif()
        endif()
    endwhile()

    set(${LINES_VAR} ${LINES} PARENT_SCOPE)
    set(${JSON_VAR} ${HASH} PARENT_SCOPE)
endfunction()
