function(cmate_tmpl_process_includes FROM VAR)
    cmate_split_lines("${FROM}" LINES)
    set(CONTENT "")

    foreach(LINE ${LINES})
        if(LINE MATCHES "^%#include <(.+)>$")
            set(INC "${CMAKE_MATCH_1}")
            cmate_tmpl_load("${INC}" TMPL)
            string(APPEND CONTENT "${TMPL}")
        else()
            string(APPEND CONTENT "${LINE}\n")
        endif()
    endforeach()

    set(${VAR} "${CONTENT}" PARENT_SCOPE)
endfunction()

macro(cmate_tmpl_block_begin)
    if(NOT IN_BLOCK)
        set(IN_BLOCK TRUE)
        string(APPEND TMPL "string(APPEND RESULT [=[\n")
    endif()
endmacro()

macro(cmate_tmpl_block_end)
    if(IN_BLOCK)
        set(IN_BLOCK FALSE)
        string(APPEND TMPL "]=])\n")
    endif()
endmacro()

function(cmate_tmpl_eval FROM TO)
    set(IN_CM_BLOCK FALSE)
    set(IN_BLOCK FALSE)
    set(LINENUM 0)
    set(INLINES "")
    set(TMPL "")
    set(RESULT "")
    set(IT_BEGIN "%{ ")
    set(IT_END " }%")
    string(LENGTH "${IT_BEGIN}" IT_LEN)

    cmate_split_lines("${FROM}" LINES)

    foreach(LINE ${LINES})
        math(EXPR LINENUM "${LINENUM}+1")

        if(LINE MATCHES "^%{CMake}%")
            # Verbatim CMake block begin
            if(IN_CM_BLOCK)
                cmate_die("line ${LINENUM}: unclosed previous block")
            else()
                set(IN_CM_BLOCK TRUE)
            endif()

            continue()
        elseif(LINE MATCHES "^%{/CMake}%")
            # Verbatim CMake block begin
            if(NOT IN_CM_BLOCK)
                cmate_die("line ${LINENUM}: no previous opened block")
            else()
                set(IN_CM_BLOCK FALSE)
            endif()

            continue()
        elseif(IN_CM_BLOCK)
            string(APPEND TMPL "${LINE}\n")
            continue()
        elseif(LINE MATCHES "^%[ \t]*$")
            # Skip empty lines
            continue()
        elseif(LINE MATCHES "^%#")
            # Skip comment lines
            continue()
        elseif(NOT LINE MATCHES "^%[ \t]+")
            if(LINE MATCHES "%{[ ]+[^ ]+[ ]+}%")
                cmate_tmpl_block_end()

                while(LINE MATCHES "%{[ ]+[^ ]+[ ]+}%")
                    # Pure CMake joy :D
                    string(FIND "${LINE}" "${IT_BEGIN}" BEGIN)
                    string(FIND "${LINE}" "${IT_END}" END)
                    math(EXPR INLINE_BEGIN "${BEGIN}+${IT_LEN}")
                    math(EXPR INLINE_LEN "${END}-${BEGIN}-${IT_LEN}")
                    string(SUBSTRING "${LINE}" 0 ${BEGIN} BEFORE)
                    string(SUBSTRING "${LINE}" ${INLINE_BEGIN} ${INLINE_LEN} INLINE)
                    string(APPEND TMPL "string(APPEND RESULT [=[${BEFORE}]=])\n")
                    string(APPEND TMPL "string(APPEND RESULT \"${INLINE}\")\n")
                    math(EXPR RPOS "${END}+${IT_LEN}")
                    string(SUBSTRING "${LINE}" ${RPOS} -1 LINE)
                endwhile()
            endif()

            cmate_tmpl_block_begin()
        else()
            cmate_tmpl_block_end()
            string(REGEX REPLACE "^% " "" LINE "${LINE}")
        endif()

        string(APPEND TMPL "${LINE}\n")
    endforeach()

    cmate_tmpl_block_end()

    cmake_language(EVAL CODE "${TMPL}")

    set(${TO} "${RESULT}" PARENT_SCOPE)
endfunction()

function(cmate_tmpl_load FILE_OR_VAR VAR)
    set(TFILE "${CMATE_TMPL_DIR}/${FILE_OR_VAR}")
    string(TOUPPER "CMATE_${FILE_OR_VAR}" TVAR)
    string(REGEX REPLACE "[-/\\.]" "_" TVAR "${TVAR}")
    set(CONTENT "")

    if(${TVAR})
        # In amalgamate mode, template is stored in a variable
        set(CONTENT "${${TVAR}}")
    elseif(EXISTS "${TFILE}")
        # In dev/filesystem mode, template is in a file
        file(STRINGS "${TFILE}" LINES)
        list(FILTER LINES EXCLUDE REGEX "^# -[*]-")
        list(JOIN LINES "\n" CONTENT)
        #string(APPEND CONTENT "\n")
    else()
        cmate_die("no template content for '${FILE_OR_VAR}'")
    endif()

    cmate_tmpl_process_includes("${CONTENT}" CONTENT)

    set(${VAR} "${CONTENT}" PARENT_SCOPE)
endfunction()

function(cmate_tmpl_process)
    set(OPTS APPEND)
    set(SINGLE FROM TO_FILE TO_VAR PRE)
    set(MULTI "")
    cmake_parse_arguments(TMPL "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    if(NOT TMPL_FROM)
        cmate_die("missing template")
    endif()

    # TODO: handle conflicting FILE/VAR
    if(NOT TMPL_TO_FILE AND NOT TMPL_TO_VAR)
        # No output specified, assume file derived from TMPL_FROM
        get_filename_component(TMPL_TO_FILE "${TMPL_FROM}" NAME)
    endif()

    cmate_tmpl_load("${TMPL_FROM}" TMPL)
    cmate_tmpl_eval("${TMPL}" CONTENT)
    string(CONFIGURE "${CONTENT}" CONTENT @ONLY)

    if(TMPL_TO_FILE)
        if(TMPL_APPEND)
            set(FILE_MODE "APPEND")
        else()
            set(FILE_MODE "WRITE")
        endif()

        file(${FILE_MODE} "${TMPL_TO_FILE}" "${CONTENT}")
        cmate_msg("wrote ${TMPL_TO_FILE}")
    elseif(TMPL_TO_VAR)
        if(TMPL_APPEND)
            set(VALUE "${TMPL_TO_VAR}")
        else()
            set(VALUE "")
        endif()

        string(APPEND VALUE "${CONTENT}")

        set(${TMPL_TO_VAR} "${VALUE}" PARENT_SCOPE)
    else()
        cmate_die("missing template destination")
    endif()
endfunction()
