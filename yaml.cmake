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

function(yaml_parse_seq LINE LINES INDENT VAR)
    set(SEQ "")

    message("==== PARSE SEQ ${INDENT}")

    if(NOT LINE STREQUAL "")
        message(FATAL_ERROR "parse_seq error")
    endif()

    while(LINES)
        list(GET LINES 0 LINE)
        yaml_count_indent("${LINE}" LEVEL)

        if(LEVEL LESS INDENT)
            # return seq
            message("<< 1 PARSE SEQ ${INDENT}")
            break()
        elseif(LEVEL GREATER INDENT)
            message(FATAL_ERROR "found bad identing on line: ${LINE}: ${LEVEL} > ${INDENT}")
        endif()

        if(NOT LINE MATCHES "^([ ]*-[ ]+)(.*)")
            if(NOT LINE MATCHES "^([ ]*-$)(.*)")
                # return seq
                message("<< 2 PARSE SEQ ${INDENT}")
                break()
            endif()
        endif()

        set(REST "${CMAKE_MATCH_2}")
        string(LENGTH "${CMAKE_MATCH_1}" INDENT2)

        if(REST MATCHES "^[^'\" ]*:[ ]*$" OR LINE MATCHES "^[^'\" ]*:[ ]+.")
            # Inline nested hash
            string(REPEAT " " ${INDENT2} PAD)
            list(POP_FRONT LINES)
            list(PREPEND LINES "${PAD}${REST}")
            yaml_parse_map("" "${LINES}" ${INDENT2} MAP)
        elseif(REST MATCHES "^-[ ]+")
            # Inline nested seq
            string(REPEAT " " ${INDENT2} PAD)
            list(POP_FRONT LINES)
            list(PREPEND LINES "${PAD}${REST}")
            yaml_parse_seq("" "${LINES}" ${INDENT2} SEQ)
        elseif(REST STREQUAL "")
            list(POP_FRONT LINES)
            message("WHOA")
        endif()
    endwhile()

    message("<< 4 PARSE SEQ ${INDENT}")
    set("LINES" ${LINES} PARENT_SCOPE)
    set("${VAR}" SEQ PARENT_SCOPE)
endfunction()

function(yaml_parse_map LINE LINES INDENT VAR)
    set(MAP "")

    message("==== PARSE MAP ${INDENT} LINE: ${LINE}")

    if(NOT LINE STREQUAL "")
        message(FATAL_ERROR "parse_seq error")
    endif()

    while(LINES)
        list(GET LINES 0 LINE)
        yaml_count_indent("${LINE}" LEVEL)

        message("MAP L=${LEVEL} I=${INDENT} LINE: ${LINE}")

        if(LEVEL LESS INDENT)
            # return map
            message("<< 1 PARSE MAP ${INDENT}")
            break()
        elseif(LEVEL GREATER INDENT)
            message(FATAL_ERROR "found bad identing on line: ${LINE}: ${LEVEL} > ${INDENT}")
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
            list(POP_FRONT LINES)
            yaml_parse_scalar(STR "${LINE}" TO_VAR VALUE)
            #message("JSON: ${KEY}=${VALUE}")
        else()
            # Indent/sub map
            list(POP_FRONT LINES)

            if(NOT LINES)
                #message("JSON: ${KEY}=null")
                break()
            endif()

            list(GET LINES 0 LINE)
            yaml_count_indent("${LINE}" INDENT2)

            if(${LINE} MATCHES "^[ ]*-")
                yaml_parse_seq("" "${LINES}" ${INDENT2} SEQ)
            else()
                if(${INDENT} GREATER_EQUAL ${INDENT2})
                    #message("JSON: ${KEY}=null")
                else()
                    yaml_parse_map("" "${LINES}" ${INDENT2} MAP)
                endif()
            endif()
        endif()
    endwhile()

    set("LINES" ${LINES} PARENT_SCOPE)
endfunction()

function(yaml_parse_doc LINES)
    while(LINES)
        list(GET LINES 0 LINE)
        message("PARSE: ${LINE}")

        if(LINE STREQUAL "---")
            list(POP_FRONT LINES)
            continue()
        elseif(LINE MATCHES "^[ ]*-")
            # Array
            yaml_parse_seq("" "${LINES}" 0 SEQ)
        elseif(LINE MATCHES "^[ ]*[^ ]")
            # Hash
            yaml_count_indent("${LINE}" LEVEL)
            yaml_parse_map("" "${LINES}" ${LEVEL} MAP)
        else()
            message(FATAL_ERROR "parse error")
        endif()
    endwhile()
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
yaml_parse_doc("${LINES}")
