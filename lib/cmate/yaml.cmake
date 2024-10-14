###############################################################################
#
# Simple YAML parser based on Perl's YAML::Tiny / Lua's tinyyaml
#
###############################################################################
function(cmate_yaml_count_indent LINE VAR)
    set(LEVEL 0)

    if(LINE MATCHES "^([ ]+)")
        string(LENGTH "${CMAKE_MATCH_1}" LEVEL)
    endif()

    set("${VAR}" ${LEVEL} PARENT_SCOPE)
endfunction()

function(cmate_yaml_unquote STR VAR)
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

function(cmate_yaml_parse_scalar)
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
        cmate_yaml_unquote(${SCALAR_STR} VALUE)

        if(VALUE MATCHES "[^0-9]" AND NOT SCALAR_IS_KEY)
            set(VALUE "\"${VALUE}\"")
        endif()
    endif()

    set(${SCALAR_TO_VAR} "${VALUE}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_parse_seq)
    set(OPTS "")
    set(SINGLE LINE INDENT PREFIX)
    set(MULTI LINES)
    cmake_parse_arguments(MY "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    set(OBJ "[]")

    if(NOT "${MY_LINE}" STREQUAL "")
        message(FATAL_ERROR "parse_seq error: '${MY_LINE}'")
    endif()

    while(1)
        list(LENGTH MY_LINES LINECOUNT)

        if(${LINECOUNT} EQUAL 0)
            break()
        endif()

        list(GET MY_LINES 0 LINE)
        cmate_yaml_count_indent("${LINE}" LEVEL)

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
            list(POP_FRONT MY_LINES)
            list(PREPEND MY_LINES "${PAD}${REST}")

            cmate_yaml_parse_map(
                LINE ""
                LINES ${MY_LINES}
                INDENT ${INDENT2}
                PREFIX SUB
            )
            set(MY_LINES ${SUB_LINES})

            string(JSON POS LENGTH "${OBJ}")
            string(JSON OBJ SET ${OBJ} ${POS} "${SUB_JSON}")
        elseif(REST MATCHES "^-[ ]+")
            # Inline nested seq
            string(REPEAT " " ${INDENT2} PAD)
            list(POP_FRONT MY_LINES)
            list(PREPEND MY_LINES "${PAD}${REST}")

            cmate_yaml_parse_seq(
                LINE ""
                LINES ${MY_LINES}
                INDENT ${INDENT2}
                PREFIX SUB
            )
            set(MY_LINES ${SUB_LINES})

            string(JSON POS LENGTH "${OBJ}")
            string(JSON OBJ SET ${OBJ} ${POS} "${SUB_JSON}")
        elseif("${REST}" STREQUAL "")
            list(POP_FRONT MY_LINES)
            message(FATAL_ERROR "WHOA")
        elseif(NOT "${REST}" STREQUAL "")
            list(GET MY_LINES 0 NEXTLINE)
            cmate_yaml_count_indent("${NEXTLINE}" INDENT2)
            list(POP_FRONT MY_LINES)
            cmate_yaml_parse_scalar(STR "${REST}" TO_VAR VALUE)

            string(JSON POS LENGTH "${OBJ}")
            string(JSON OBJ SET ${OBJ} ${POS} ${VALUE})
        endif()
    endwhile()

    set("${MY_PREFIX}_LINES" ${MY_LINES} PARENT_SCOPE)
    set("${MY_PREFIX}_JSON" ${OBJ} PARENT_SCOPE)
endfunction()

function(cmate_yaml_parse_map)
    set(OPTS "")
    set(SINGLE LINE INDENT PREFIX)
    set(MULTI LINES)
    cmake_parse_arguments(MY "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    set(OBJ "{}")

    if(NOT "${MY_LINE}" STREQUAL "")
        message(FATAL_ERROR "parse_map error: '${MY_LINE}'")
    endif()

    while(1)
        list(LENGTH MY_LINES LINECOUNT)

        if(${LINECOUNT} EQUAL 0)
            break()
        endif()

        list(GET MY_LINES 0 LINE)
        cmate_yaml_count_indent("${LINE}" LEVEL)

        if(LEVEL LESS MY_INDENT)
            # return map
            break()
        elseif(LEVEL GREATER MY_INDENT)
            message(FATAL_ERROR "found bad identing on line: ${LINE}: ${LEVEL} > ${MY_INDENT}")
        endif()

        if(${LINE} MATCHES "^([ ]*(.+):)")
            string(LENGTH "${CMAKE_MATCH_1}" TOSTRIP)
            cmate_yaml_parse_scalar(STR "${CMAKE_MATCH_2}" TO_VAR KEY IS_KEY 1)
            string(SUBSTRING ${LINE} ${TOSTRIP} -1 LINE)
        else()
            message(FATAL_ERROR "failed to classify line: ${LINE}")
        endif()

        if(NOT "${LINE}" STREQUAL "")
            # We have a value
            list(POP_FRONT MY_LINES)
            cmate_yaml_parse_scalar(STR "${LINE}" TO_VAR VALUE)
            string(JSON OBJ SET ${OBJ} ${KEY} ${VALUE})
        else()
            # Indent/sub map
            list(POP_FRONT MY_LINES)
            list(LENGTH MY_LINES LINECOUNT)

            if(LINECOUNT EQUAL 0)
                string(JSON OBJ SET ${OBJ} ${KEY} "null")
                break()
            endif()

            list(GET MY_LINES 0 LINE)
            cmate_yaml_count_indent("${LINE}" INDENT2)

            if("${LINE}" MATCHES "^[ ]*-")
                cmate_yaml_parse_seq(
                    LINE ""
                    LINES "${MY_LINES}"
                    INDENT ${INDENT2}
                    PREFIX SUB
                )
                set(MY_LINES ${SUB_LINES})

                string(JSON OBJ SET ${OBJ} ${KEY} "${SUB_JSON}")
            else()
                if(${MY_INDENT} GREATER_EQUAL ${INDENT2})
                    string(JSON OBJ SET ${OBJ} ${KEY} "null")
                else()
                    cmate_yaml_parse_map(
                        LINE ""
                        LINES "${MY_LINES}"
                        INDENT ${INDENT2}
                        PREFIX SUB
                    )
                    set(MY_LINES ${SUB_LINES})

                    string(JSON OBJ SET ${OBJ} ${KEY} "${SUB_JSON}")
                endif()
            endif()
        endif()
    endwhile()

    set("${MY_PREFIX}_LINES" ${MY_LINES} PARENT_SCOPE)
    set("${MY_PREFIX}_JSON" ${OBJ} PARENT_SCOPE)
endfunction()

function(cmate_yaml_parse_doc LINES VAR)
    while(LINES)
        list(GET LINES 0 LINE)

        if(LINE STREQUAL "---")
            list(POP_FRONT LINES)
            continue()
        elseif(LINE MATCHES "^[ ]*-")
            # Array
            cmate_yaml_parse_seq(
                LINE ""
                LINES ${LINES}
                INDENT 0
                PREFIX SUB
            )
            set(LINES ${SUB_LINES})
        elseif(LINE MATCHES "^[ ]*[^ ]")
            # Hash
            cmate_yaml_count_indent("${LINE}" LEVEL)
            cmate_yaml_parse_map(
                LINE ""
                LINES ${LINES}
                INDENT ${LEVEL}
                PREFIX SUB
            )
            set(LINES ${SUB_LINES})
        else()
            message(FATAL_ERROR "parse error")
        endif()
    endwhile()

    set(${VAR} "${SUB_JSON}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_dump_scalar)
    set(OPTS IS_KEY)
    set(SINGLE STR TO_VAR)
    set(MULTI "")
    cmake_parse_arguments(SCALAR "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    string(JSON T ERROR_VARIABLE ERR TYPE "${SCALAR_STR}")

    if(T STREQUAL "NULL")
        set(CONTENT "~")
    elseif("${SCALAR_STR}" STREQUAL "")
        set(CONTENT "''")
    elseif(T STREQUAL "NUMBER")
        if(SCALAR_IS_KEY)
            set(CONTENT "'${SCALAR_STR}'")
        else()
            set(CONTENT "${SCALAR_STR}")
        endif()
    elseif("${SCALAR_STR}" MATCHES "^[~!@#%&*|>?:,'\"`{} ]|^-+$|:$]")
        set(CONTENT "'${SCALAR_STR}'")
    else()
        set(CONTENT "${SCALAR_STR}")
    endif()

    set("${SCALAR_TO_VAR}" "${CONTENT}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_dump_seq)
    set(OPTS "")
    set(SINGLE JSON TO_VAR INDENT)
    set(MULTI "")
    cmake_parse_arguments(SEQ "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    string(REPEAT "  " ${SEQ_INDENT} INDENT)
    set(CONTENT "")

    cmate_json_array_to_list("${SEQ_JSON}" ITEMS)

    foreach(ITEM ${ITEMS})
        set(LINE "${INDENT}-")
        cmate_yaml_get_type(JSON "${ITEM}" VAR T)

        if(T STREQUAL "SCALAR")
            cmate_yaml_dump_scalar(STR "${ITEM}" TO_VAR SCALAR)
            string(APPEND LINE " ${SCALAR}")
            string(APPEND CONTENT "${LINE}\n")
        elseif(T STREQUAL "ARRAY")
            string(JSON N LENGTH ${ITEM})

            if(${N} GREATER 0)
                string(APPEND CONTENT "${LINE}\n")
                math(EXPR SINDENT "${INDENT}+1")
                cmate_yaml_dump_seq(JSON "${ITEM}" TO_VAR ARRAY INDENT ${SINDENT})
                string(APPEND CONTENT "${ARRAY}\n")
            else()
                string(APPEND CONTENT "[]\n")
            endif()
        elseif(T STREQUAL "OBJECT")
            string(JSON N LENGTH ${ITEM})

            if(${N} GREATER 0)
                string(APPEND CONTENT "${LINE}\n")
                math(EXPR SINDENT "${INDENT}+1")
                cmate_yaml_dump_seq(JSON "${ITEM}" TO_VAR HASH INDENT ${SINDENT})
                string(APPEND CONTENT "${HASH}\n")
            else()
                string(APPEND CONTENT "{}\n")
            endif()
        endif()
    endforeach()

    set(${SEQ_TO_VAR} "${CONTENT}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_dump_map)
    set(OPTS "")
    set(SINGLE JSON TO_VAR INDENT)
    set(MULTI "")
    cmake_parse_arguments(MAP "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    string(REPEAT "  " ${MAP_INDENT} INDENT)
    set(CONTENT "")

    string(JSON N LENGTH ${MAP_JSON})

    if(N EQUAL 0)
        return()
    else()
        math(EXPR COUNT "${N}-1")
    endif()

    foreach(I RANGE ${COUNT})
        string(JSON KEY MEMBER ${MAP_JSON} ${I})
        string(JSON ITEM GET ${MAP_JSON} "${KEY}")
        cmate_yaml_dump_scalar(STR "${KEY}" TO_VAR NAME IS_KEY 1)
        set(LINE "${INDENT}${KEY}:")

        cmate_yaml_get_type(JSON ${MAP_JSON} KEY "${KEY}" VAR T)

        if(T STREQUAL "SCALAR")
            cmate_yaml_dump_scalar(STR "${ITEM}" TO_VAR SCALAR)
            string(APPEND LINE " ${SCALAR}")
            string(APPEND CONTENT "${LINE}\n")
        elseif(T STREQUAL "ARRAY")
            string(JSON N LENGTH ${ITEM})

            if(${N} GREATER 0)
                string(APPEND CONTENT "${LINE}\n")
                math(EXPR SINDENT "${INDENT}+1")
                cmate_yaml_dump_seq(JSON "${ITEM}" TO_VAR ARRAY INDENT ${SINDENT})
                string(APPEND CONTENT "${ARRAY}\n")
            else()
                string(APPEND CONTENT "[]\n")
            endif()
        elseif(T STREQUAL "OBJECT")
            string(JSON N LENGTH ${ITEM})

            if(${N} GREATER 0)
                string(APPEND CONTENT "${LINE}\n")
                math(EXPR SINDENT "${INDENT}+1")
                cmate_yaml_dump_seq(JSON "${ITEM}" TO_VAR HASH INDENT ${SINDENT})
                string(APPEND CONTENT "${HASH}\n")
            else()
                string(APPEND CONTENT "{}\n")
            endif()
        endif()
    endforeach()

    set(${MAP_TO_VAR} "${CONTENT}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_get_type)
    set(OPTS "")
    set(SINGLE JSON KEY VAR)
    set(MULTI "")
    cmake_parse_arguments(GT "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    string(JSON T ERROR_VARIABLE ERR TYPE ${GT_JSON} ${GT_KEY})

    if(T STREQUAL "NULL" OR T STREQUAL "NUMBER" OR T STREQUAL "STRING" OR T STREQUAL "BOOLEAN")
        set(T "SCALAR")
    endif()

    set(${GT_VAR} ${T} PARENT_SCOPE)
endfunction()

function(cmate_yaml_dump JSON VAR)
    cmate_yaml_get_type(JSON "${JSON}" VAR T)
    set(DOC "---")

    set(INDENT 0)

    if(T STREQUAL "SCALAR")
        cmate_yaml_dump_scalar(STR "${JSON}" TO_VAR CONTENT)
    elseif(T STREQUAL "ARRAY")
        cmate_yaml_dump_seq(JSON "${JSON}" TO_VAR CONTENT INDENT ${INDENT})
    elseif(T STREQUAL "OBJECT")
        cmate_yaml_dump_map(JSON "${JSON}" TO_VAR CONTENT INDENT ${INDENT})
    endif()

    if(CONTENT)
        string(APPEND DOC "\n${CONTENT}")
    endif()

    set(${VAR} "${DOC}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_load FILE VAR)
    set(LINES "")

    if(EXISTS ${FILE})
        file(STRINGS ${FILE} LINES)
    endif()

    cmate_yaml_parse_doc("${LINES}" JSON)

    set("${VAR}" "${JSON}" PARENT_SCOPE)
endfunction()

function(cmate_yaml_save FILE JSON)
    cmate_yaml_dump("${JSON}" YAML)
    file(WRITE ${FILE} ${YAML})
endfunction()
