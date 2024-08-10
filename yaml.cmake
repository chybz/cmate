# See POYO in upstream

set(SOURCE [=[
---
name: cucumber_messages
version: 0.1.0
namespace: cucumber
std: 17
packages:
  cmake:
    - nlohmann_json:
deps:
  - nlohmann/json@v3.11.3:
    - -DJSON_BuildTests=OFF
  - other
]=])

set(YAML_POS 0)
string(LENGTH SOURCE YAML_MAX_POS)
set(YAML_MAX_POS 0)

set(RE_COMMENT "^[ ]*#.*$\n")
set(RE_BLANK_LINE "^[ \t]*$\n")
set(RE_DASHES "^---\n")
list(APPEND RULES )

function(yaml_count_indent LINE VAR)
    set(LEVEL 0)

    if(LINE MATCHES "^([ ]+)")
        string(LENGTH "${CMAKE_MATCH_1}" LEVEL)
    endif()

    set("${VAR}" ${LEVEL} PARENT_SCOPE)
endfunction()

function(yaml_unquote STR VAR)
    set(VAL "")

    if(STR MATCHES "^\"((\\\\.|[^\"])*)?\"$")
        set(VAL "${CMAKE_MATCH_1}")
    elseif(STR MATCHES "^'([^']*(''[^']*)*)?'$")
        set(VAL "${CMAKE_MATCH_1}")
    else()
        set(VAL "${STR}")
    endif()

    set(${VAR} ${VAL} PARENT_SCOPE)
endfunction()

function(yaml_parse_scalar)
    set(OPTS IS_KEY)
    set(SINGLE STR TO_VAR)
    set(MULTI "")
    cmake_parse_arguments(SCALAR "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    set(VALUE "")

    # Trim whitespace and comments
    string(REGEX REPLACE "^[ ]+" "" SCALAR_STR ${SCALAR_STR})
    string(REGEX REPLACE "[ ]+$" "" SCALAR_STR ${SCALAR_STR})
    string(REGEX REPLACE "#.*$" "" STR ${SCALAR_STR})

    if("${SCALAR_STR}" STREQUAL "~")
        set(VALUE "null")
    else()
        yaml_unquote(${SCALAR_STR} VALUE)

        if(VALUE MATCHES "[^0-9]" AND NOT SCALAR_IS_KEY)
            set(VALUE "\"${VALUE}\"")
        endif()
    endif()

    set(${SCALAR_TO_VAR} "${VALUE}" PARENT_SCOPE)
endfunction()

function(yaml_parse_seq)
    message("PSEQ: ARGV=${ARGV}")

    set(OPTS "")
    set(SINGLE LINE INDENT LINES_VAR JSON_VAR)
    set(MULTI ALL_LINES)
    cmake_parse_arguments(MY "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    set(OBJ "[]")

    if(NOT "${MY_LINE}" STREQUAL "")
        message(FATAL_ERROR "parse_seq error: '${MY_LINE}'")
    endif()

    while(MY_ALL_LINES)
        list(LENGTH MY_ALL_LINES LINECOUNT)
        list(GET MY_ALL_LINES 0 LINE)
        yaml_count_indent("${LINE}" LEVEL)

        if(LEVEL LESS MY_INDENT)
            # return seq
            break()
        elseif(LEVEL GREATER MY_INDENT)
            message(FATAL_ERROR "found bad identing on line: ${LINE}: ${LEVEL} > ${MY_INDENT}")
        endif()

        if(NOT LINE MATCHES "^([ ]*-[ ]+)(.*)")
            if(NOT LINE MATCHES "^([ ]*-$)(.*)")
                # return seq
                break()
            endif()
        endif()

        set(REST "${CMAKE_MATCH_2}")
        string(LENGTH "${CMAKE_MATCH_1}" INDENT2)

        if(REST MATCHES "^[^'\" ]*:[ ]*$" OR LINE MATCHES "^[^'\" ]*:[ ]+.")
            # Inline nested hash
            string(REPEAT " " ${INDENT2} PAD)
            list(POP_FRONT MY_ALL_LINES)
            list(PREPEND MY_ALL_LINES "${PAD}${REST}")

            yaml_parse_map(
                LINE ""
                ALL_LINES ${MY_ALL_LINES}
                INDENT ${INDENT2}
                LINES_VAR MY_ALL_LINES
                JSON_VAR SUBMAP
            )

            string(JSON POS LENGTH "${OBJ}")
            string(JSON ARRAY SET ${OBJ} ${POS} ${SUBMAP})
        elseif(REST MATCHES "^-[ ]+")
            # Inline nested seq
            string(REPEAT " " ${INDENT2} PAD)
            list(POP_FRONT MY_ALL_LINES)
            list(PREPEND MY_ALL_LINES "${PAD}${REST}")

            yaml_parse_seq(
                LINE ""
                ALL_LINES ${MY_ALL_LINES}
                INDENT ${INDENT2}
                LINES_VAR MY_ALL_LINES
                JSON_VAR SUBSEQ
            )

            string(JSON POS LENGTH "${OBJ}")
            string(JSON ARRAY SET ${OBJ} ${POS} ${SUBSEQ})
        elseif(REST STREQUAL "")
            list(POP_FRONT MY_ALL_LINES)
            message("WHOA")
        elseif(NOT REST STREQUAL "")
            if(LINECOUNT GREATER 0)
                list(GET MY_ALL_LINES 0 NEXTLINE)
                yaml_count_indent("${NEXTLINE}" INDENT2)
                list(POP_FRONT MY_ALL_LINES)
                yaml_parse_scalar(STR "${REST}" TO_VAR VALUE)

                string(JSON POS LENGTH "${OBJ}")
                string(JSON ARRAY SET ${OBJ} ${POS} ${VALUE})
            endif()
        endif()
    endwhile()

    set(${MY_ALL_LINES_VAR} ${MY_ALL_LINES} PARENT_SCOPE)
    set(${MY_JSON_VAR} ${OBJ} PARENT_SCOPE)
endfunction()

function(yaml_parse_map)
    message("PMAP: ARGV=${ARGV}")

    set(OPTS "")
    set(SINGLE LINE INDENT LINES_VAR JSON_VAR)
    set(MULTI ALL_LINES)
    cmake_parse_arguments(MY "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    set(OBJ "{}")

    if(NOT "${MY_LINE}" STREQUAL "")
        message(FATAL_ERROR "parse_map error: '${MY_LINE}'")
    endif()

    while(MY_ALL_LINES)
        list(GET MY_ALL_LINES 0 LINE)
        yaml_count_indent("${LINE}" LEVEL)

        if(LEVEL LESS MY_INDENT)
            # return map
            break()
        elseif(LEVEL GREATER MY_INDENT)
            message(FATAL_ERROR "found bad identing on line: ${LINE}: ${LEVEL} > ${MY_INDENT}")
        endif()

        if(${LINE} MATCHES "^([ ]*(.+):)")
            string(LENGTH "${CMAKE_MATCH_1}" TOSTRIP)
            yaml_parse_scalar(STR "${CMAKE_MATCH_2}" TO_VAR KEY IS_KEY 1)
            string(SUBSTRING ${LINE} ${TOSTRIP} -1 LINE)
        else()
            message(FATAL_ERROR "failed to classify line: ${LINE}")
        endif()

        if(NOT "${LINE}" STREQUAL "")
            # We have a value
            list(POP_FRONT MY_ALL_LINES)
            yaml_parse_scalar(STR "${LINE}" TO_VAR VALUE)
            string(JSON HASH SET ${OBJ} ${KEY} ${VALUE})
        else()
            # Indent/sub map
            list(POP_FRONT MY_ALL_LINES)

            if(NOT LINES)
                string(JSON HASH SET ${OBJ} ${KEY} "null")
                break()
            endif()

            list(GET LINES 0 LINE)
            yaml_count_indent("${LINE}" INDENT2)

            if(${LINE} MATCHES "^[ ]*-")
                yaml_parse_seq(
                    LINE ""
                    ALL_LINES "${MY_ALL_LINES}"
                    INDENT ${INDENT2}
                    LINES_VAR MY_ALL_LINES
                    JSON_VAR SUBSEQ
                )
                string(JSON HASH SET ${OBJ} ${KEY} ${SUBSEQ})
            else()
                if(${MY_INDENT} GREATER_EQUAL ${INDENT2})
                    string(JSON HASH SET ${OBJ} ${KEY} "null")
                else()
                    yaml_parse_map(
                        LINE ""
                        ALL_LINES "${MY_ALL_LINES}"
                        INDENT ${INDENT2}
                        LINES_VAR MY_ALL_LINES
                        JSON_VAR SUBMAP
                    )

                    string(JSON HASH SET ${OBJ} ${KEY} ${SUBMAP})
                endif()
            endif()
        endif()
    endwhile()

    set(${MY_ALL_LINES_VAR} ${MY_ALL_LINES} PARENT_SCOPE)
    set(${MY_JSON_VAR} ${OBJ} PARENT_SCOPE)
endfunction()

function(yaml_parse_doc LINES VAR)
    while(LINES)
        list(GET LINES 0 LINE)
        message("PARSE: ${LINE}")

        if(LINE STREQUAL "---")
            list(POP_FRONT LINES)
            continue()
        elseif(LINE MATCHES "^[ ]*-")
            # Array
            yaml_parse_seq(
                LINE ""
                ALL_LINES ${LINES}
                INDENT 0
                LINES_VAR "LINES"
                JSON_VAR "JSON"
            )
        elseif(LINE MATCHES "^[ ]*[^ ]")
            # Hash
            yaml_count_indent("${LINE}" LEVEL)
            yaml_parse_map(
                LINE ""
                ALL_LINES ${LINES}
                INDENT ${LEVEL}
                LINES_VAR "LINES"
                JSON_VAR "JSON"
            )
        else()
            message(FATAL_ERROR "parse error")
        endif()
    endwhile()

    message("PARSED JSON: ${JSON}")
endfunction()

function(yaml_load SOURCE VAR)
    set(LINES "")

    while(SOURCE MATCHES "^([^\r\n]*)\r?\n(.*)")
        list(APPEND LINES "${CMAKE_MATCH_1}")
        set(SOURCE "${CMAKE_MATCH_2}")
    endwhile()

    set("${VAR}" "${LINES}" PARENT_SCOPE)
endfunction()

yaml_load("${SOURCE}" LINES)
yaml_parse_doc("${LINES}" JSON)
