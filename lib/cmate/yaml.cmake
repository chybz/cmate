function(cmate_yaml_type PATH VAR)
    set(RES "UNKNOWN")

    foreach(TYPE "scalar" "array" "hash")
        cmake_language(CALL "cmate_yaml_is_${TYPE}" ${PATH} IS)

        if(IS)
            string(TOUPPER ${TYPE} RES)
            break()
        endif()
    endforeach()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_yaml_is_scalar PATH VAR)
    set(RES 0)

    cmate_yaml_is_array(${PATH} IS_ARRAY)
    cmate_yaml_is_hash(${PATH} IS_HASH)

    if(NOT (${IS_ARRAY} OR ${IS_HASH}))
        if(DEFINED ${PATH})
            set(RES 1)
        endif()
    endif()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_yaml_is_array PATH VAR)
    set(RES 0)

    if(DEFINED ${PATH}.__values__)
        set(RES 1)
    endif()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_yaml_values PATH VAR)
    set(${VAR} "${${PATH}.__values__}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_is_hash PATH VAR)
    set(RES 0)

    if(DEFINED ${PATH}.__keys__)
        set(RES 1)
    endif()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_yaml_keys PATH VAR)
    set(${VAR} "${${PATH}.__keys__}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_load FILE ROOT)
    set(LINES "")
    set(INDENTS "")

    if(EXISTS ${FILE})
        file(STRINGS ${FILE} LINES)
    endif()

    list(LENGTH LINES PREV_LINE_COUNT)

    while(LINES)
        list(GET LINES 0 LINE)
        set(INDENTS "")

        if(LINE MATCHES "^[ ]*-([ ]|$|-+$)")
            list(APPEND INDENTS 0)
            cmate_yaml_load_array("${ROOT}" "${INDENTS}" "${LINES}" "LINES")
        elseif(LINE MATCHES "^([ ]*)[^ ]")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            list(APPEND INDENTS ${LEN})
            cmate_yaml_load_hash("${ROOT}" "${INDENTS}" "${LINES}" "LINES")
        endif()

        list(LENGTH LINES LINE_COUNT)

        if(NOT ${LINE_COUNT} LESS ${PREV_LINE_COUNT})
            cmate_die("cmate_yaml_load: no lines consumed")
        endif()
    endwhile()
endfunction()

function(cmate_yaml_load_scalar STR VAR)
    set(VALUE "")

    # Trim whitespace and comments
    string(REGEX REPLACE "^[ ]+" "" STR ${STR})
    string(REGEX REPLACE "[ ]+$" "" STR ${STR})
    string(REGEX REPLACE "#.*$" "" STR ${STR})

    if("${STR}" STREQUAL "~")
        set(VALUE "")
    else()
        cmate_unquote(${STR} VALUE)
    endif()

    set(${VAR} "${VALUE}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_load_array ROOT INDENTS LINES VAR)
    set(VALUES "")

    while(LINES)
        list(GET LINES 0 LINE)

        # Check indent level
        if(${LINE} MATCHES "^([ ]*)")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            list(GET INDENTS -1 INDENT)

            if(${LEN} LESS ${INDENT})
                break()
            elseif(${LEN} GREATER ${INDENT})
                cmate_die("bad indenting: ${LINE}")
            endif()
        else()
            # Should not happen
            cmate_die("invalid array line: ${LINE}")
        endif()

        if(${LINE} MATCHES "^([ ]*-[ ]+)[^\\'\"][^ ]*[ ]*:([ ]+|$)?")
            cmate_msg("LA 1")
            # Inline nested hash
            string(LENGTH "${CMAKE_MATCH_1}" INDENT2)
            list(APPEND INDENTS ${INDENT2})

            string(REPLACE "-" " " LINE ${LINE})
            list(POP_FRONT LINES)
            list(PREPEND LINES ${LINE})

            cmate_yaml_load_hash(${ROOT} ${INDENTS} ${LINES} LINES)
        elseif(${LINE} MATCHES "^[ ]*-([ ]*)(.+)[ ]*$")
            # Array entry with value
            list(POP_FRONT LINES)
            cmate_yaml_load_scalar("${CMAKE_MATCH_2}" VALUE)
            list(APPEND VALUES ${VALUE})
        endif()
    endwhile()

    set(${VAR} ${LINES} PARENT_SCOPE)
    cmate_appendg(${ROOT}.__values__ "${VALUES}")
endfunction()

function(cmate_yaml_load_hash ROOT INDENTS LINES VAR)
    set(KEYS "")

    while(LINES)
        list(GET LINES 0 LINE)

        # Check indent level
        if(${LINE} MATCHES "^([ ]*)")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            list(GET INDENTS -1 INDENT)

            if(${LEN} LESS ${INDENT})
                break()
            elseif(${LEN} GREATER ${INDENT})
                cmate_die("bad indenting: ${LINE}")
            endif()
        else()
            # Should not happen
            cmate_die("invalid hash line: ${LINE}")
        endif()

        if(${LINE} MATCHES "^([ ]*(.+):)")
            string(LENGTH "${CMAKE_MATCH_1}" TOSTRIP)
            cmate_yaml_load_scalar("${CMAKE_MATCH_2}" KEY)
            list(APPEND KEYS ${KEY})
            string(SUBSTRING ${LINE} ${TOSTRIP} -1 LINE)
        endif()

        set(SUBROOT "${ROOT}.${KEY}")

        if(LINE)
            # We have a value
            cmate_yaml_load_scalar("${LINE}" VALUE)
            cmate_setg("${ROOT}.${KEY}" "${VALUE}")
            list(POP_FRONT LINES)
        else()
            # Indent/sub hash
            list(POP_FRONT LINES)

            if(NOT LINES)
                break()
            endif()

            list(GET LINES 0 LINE)

            if(${LINE} MATCHES "^([ ]*)-")
                string(LENGTH "${CMAKE_MATCH_1}" LEN)
                list(APPEND INDENTS ${LEN})
                cmate_yaml_load_array(
                    "${SUBROOT}" "${INDENTS}" "${LINES}" "LINES"
                )
            elseif(${LINE} MATCHES "^([ ]*).")
                string(LENGTH "${CMAKE_MATCH_1}" LEN)
                list(APPEND INDENTS ${LEN})
                cmate_yaml_load_hash(
                    "${SUBROOT}" "${INDENTS}" "${LINES}" "LINES"
                )
            endif()
        endif()
    endwhile()

    set(${VAR} ${LINES} PARENT_SCOPE)
    cmate_appendg("${ROOT}.__keys__" "${KEYS}")
endfunction()

