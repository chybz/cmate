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
        string(LENGTH "${CMATE_MATCH_1}" LEVEL)
    endif()

    set("${VAR}" LEVEL PARENT_SCOPE)
endfunction()

function(yaml_parse_seq LINE LINES INDENT VAR)
    set(SEQ "")

    if(NOT LINE STREQUAL "")
        message(FATAL_ERROR "parse_seq error")
    endif()

    while(LINES)
        list(GET LINES 0 LINE)
        yaml_count_indent("${LINE}" LEVEL)

        if(LEVEL LESS INDENT)
            # return seq
            break()
        elseif(LEVEL GREATER INDENT)
            message(FATAL_ERROR "found bad identing on line: ${LINE}")
        endif()

        if(NOT LINE MATCHES "(-[ ]+)(.*)")
            if(NOT LINE MATCHES "-$(.*)")
                # return seq
                break()
            endif()
        else()
            set(REST "${CMATE_MATCH_2}")
            if(LINE MATCHES "-$")
                set(LINE "")
            else()
                # return seq
                break()
            endif()
        endif()

        string(LENGTH LINE INDENT2)

        if(LINE MATCHES "^[^'\" ]*:[ ]*$" OR LINE MATCHES "^[^'\" ]*:[ ]+.")
            # Inline nested hash
        endif()
    endwhile()

    set("${VAR}" SEQ PARENT_SCOPE)
endfunction()

function(yaml_parse_doc LINES)
    while(LINES)
        list(GET LINES 0 LINE)

        if(LINE STREQUAL "---")
            continue()
        elseif(LINE MATCHES "^[ ]*-")
            # Array
            yaml_parse_seq("" "${LINES}" 0)
        elseif(LINE MATCHES "^[ ]*[^ ]")
            # Hash
            yaml_count_indent("${LINE}" LEVEL)
            yaml_parse_map("" "${LINES}" ${LEVEL})
        else()
            message(FATAL_ERROR "parse error")
        endif()
    endwhile()
endfunction()

function(yaml_load SOURCE VAR)
    set(LINES "")

    while(SOURCE MATCHES "^(.*)\r?\n(.*)")
        list(APPEND LINES "${CMATE_MATCH_1}")
        set(SOURCE "${CMATE_MATCH_2}")
    endwhile()

    set("${VAR}" LINES PARENT_SCOPE)
endfunction()

yaml_load("${SOURCE}" LINES)
yaml_parse_doc(${LINES})
