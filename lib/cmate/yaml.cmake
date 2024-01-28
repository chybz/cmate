function(cmate_yaml_load FILE PREFIX)
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
            cmate_yaml_load_array("${PREFIX}" "${INDENTS}" "${LINES}" "LINES")
        elseif(LINE MATCHES "^([ ]*)[^ ]")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            list(APPEND INDENTS ${LEN})
            cmate_yaml_load_hash("${PREFIX}" "${INDENTS}" "${LINES}" "LINES")
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

function(cmate_yaml_load_array PREFIX INDENTS LINES VAR)
    set(VALUES "")

    while(LINES)
        list(GET LINES 0 LINE)

        # Check indent level
        if(${LINE} MATCHES "^([ ]*)")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            list(GET INDENTS -1 INDENT)

            if(${LEN} LESS ${INDENT})
                return()
            elseif(${LEN} GREATER ${INDENT})
                cmate_die("bad indenting: ${LINE}")
            endif()
        else()
            # Should not happen
            cmate_die("invalid array line: ${LINE}")
        endif()

        if(${LINE} MATCHES "^([ ]*-[ ]+)[^\\'\"][^ ]*[ ]*:([ ]+|$)?")
            # Inline nested hash
            string(LENGTH "${CMAKE_MATCH_1}" INDENT2)
            list(APPEND INDENTS ${INDENT2})

            string(REPLACE "-" " " LINE ${LINE})
            list(POP_FRONT LINES)
            list(PREPEND LINES ${LINE})

            cmate_yaml_load_hash(${PREFIX} ${INDENTS} ${LINES} LINES)
        elseif(${LINE} MATCHES "^[ ]*-([ ]*)(.+)[ ]*$")
            # Array entry with value
            list(POP_FRONT LINES)
            cmate_yaml_load_scalar("${CMAKE_MATCH_2}" VALUE)
            list(APPEND VALUES ${VALUE})
        endif()
    endwhile()

    set(${VAR} ${LINES} PARENT_SCOPE)
    cmate_setg("${PREFIX}_ARRAY" ${VALUES})
endfunction()

function(cmate_yaml_load_hash PREFIX INDENTS LINES VAR)
    set(KEYS "")

    while(LINES)
        list(GET LINES 0 LINE)

        # Check indent level
        if(${LINE} MATCHES "^([ ]*)")
            string(LENGTH "${CMAKE_MATCH_1}" LEN)
            list(GET INDENTS -1 INDENT)

            if(${LEN} LESS ${INDENT})
                return()
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

        set(SUBPREFIX "${PREFIX}_${KEY}")

        if(LINE)
            # We have a value
            cmate_yaml_load_scalar("${LINE}" VALUE)
            cmate_setg("${PREFIX}_${KEY}" "${VALUE}")
            list(POP_FRONT LINES)
        else()
            # Indent/sub hash
            list(POP_FRONT LINES)

            if(NOT LINES)
                return()
            endif()

            list(GET LINES 0 LINE)

            if(${LINE} MATCHES "^([ ]*)-")
                string(LENGTH "${CMAKE_MATCH_1}" LEN)
                list(APPEND INDENTS ${LEN})
                cmate_yaml_load_array(
                    "${SUBPREFIX}" "${INDENTS}" "${LINES}" "LINES"
                )
            elseif(${LINE} MATCHES "^([ ]*).")
                string(LENGTH "${CMAKE_MATCH_1}" LEN)
                list(APPEND INDENTS ${LEN})
                cmate_yaml_load_hash(
                    "${SUBPREFIX}" "${INDENTS}" "${LINES}" "LINES"
                )
            endif()
        endif()
    endwhile()

    set(${VAR} ${LINES} PARENT_SCOPE)
    cmate_setg("${PREFIX}__keys__" "${KEYS}")
endfunction()

