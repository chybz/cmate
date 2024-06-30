macro(cmate_tmpl_add WHAT)
    string(APPEND TMPL "${WHAT}\n")
endmacro()

function(cmate_tmpl_eval)
    set(OPTS "")
    set(SINGLE FROM TO)
    set(MULTI "")
    cmake_parse_arguments(TMPL "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    if(NOT TMPL_FROM)
        cmate_die("missing template")
    endif()

    if(NOT TMPL_TO)
        get_filename_component(TMPL_TO "${TMPL_FROM}" NAME)
    endif()

    set(IN_CM_BLOCK FALSE)
    set(IN_BLOCK FALSE)
    set(LINENUM 0)
    set(INLINES "")
    set(TMPL "")

    cmate_tmpl_add("set(TMPL_PROCESS TRUE)")

    # TODO: add support for var/val eval arguments

    file(STRINGS "${TMPL_FROM}" LINES)

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
        elseif(LINE MATCHES "^%[ \t]*$")
            # Skip empty lines
            continue()
        elseif(LINE MATCHES "^%#")
            # Skip comment lines
            continue()
        elseif(IN_CM_BLOCK)
            cmate_tmpl_add("${LINE}")
            continue()
        elseif(NOT LINE MATCHES "^%[ \t]+")
            if(NOT IN_BLOCK)
                set(IN_BLOCK TRUE)
                cmate_tmpl_add("message([=[")
            endif()

            set(INLINES "")

            # Replace inlines
            while(LINE MATCHES "(.*)%{[ \t]+(.*)")
                set(BEFORE "${CMAKE_MATCH_1}")
                set(REST "${CMAKE_MATCH_2}")

                if(REST MATCHES "(.*)[ \t]+}%(.*)")
                    set(INLINE "${CMAKE_MATCH_1}")
                    set(REST "${CMAKE_MATCH_2}")
                    list(LENGTH INLINES IDX)
                    list(APPEND INLINES "${INLINE}")
                    set(LINE "${BEFORE}__INLINE_${IDX}__${REST}")
                else()
                    cmate_die("unmatched inline in: ${LINE}")
                endif()
            endwhile()

            # Escape text line
            #string(REGEX REPLACE "\\\\" "\\\\\\\\" LINE "${LINE}")
            string(REGEX REPLACE "\\$" "\\\\$" LINE "${LINE}")
            cmate_msg("ESCAPED: ${LINE}")

            set(IDX 0)

            foreach(INLINE ${INLINES})
                string(REPLACE "__INLINE_${IDX}__" "${INLINE}")
                math(EXPR IDX "${IDX}+1")
            endforeach()
        else()
            if(IN_BLOCK)
                # Close previous block
                set(IN_BLOCK FALSE)
                cmate_tmpl_add("]=])")
            endif()

            string(REGEX REPLACE "^%" "" LINE "${LINE}")
            string(REGEX REPLACE "^ " "" LINE "${LINE}")
        endif()

        cmate_tmpl_add("${LINE}")
    endforeach()

    if(IN_BLOCK)
        # Close previous block
        set(IN_BLOCK FALSE)
        cmate_tmpl_add("]=])")
    endif()

    cmate_msg("TEMPLATE IS:\n${TMPL}")
endfunction()

function(cmate_tmpl_configure FILE_BASE VAR)
    set(VALUE "${${VAR}}")
    set(PRE "")

    if(${ARGC} GREATER 2)
        set(PRE "${ARGV2}")
    endif()

    set(TFILE "${CMATE_TMPL_DIR}/${FILE_BASE}")
    string(TOUPPER "CMATE_${FILE_BASE}" TVAR)
    string(REGEX REPLACE "[-/\\.]" "_" TVAR "${TVAR}")
    set(CONTENT "")

    if(${TVAR})
        # In amalgamate mode
        set(CONTENT "${${TVAR}}")
    elseif(EXISTS "${TFILE}")
        # In dev/filesystem mode
        file(STRINGS "${TFILE}" LINES)
        list(FILTER LINES EXCLUDE REGEX "^# -[*]-")
        list(JOIN LINES "\n" CONTENT)
        string(APPEND CONTENT "\n")
    else()
        cmate_die("no template content for '${FILE_BASE}'")
    endif()

    string(CONFIGURE "${CONTENT}" CONTENT @ONLY)

    if(VALUE)
        string(APPEND VALUE "${PRE}")
    endif()

    string(APPEND VALUE "${CONTENT}")

    set(${VAR} "${VALUE}" PARENT_SCOPE)
endfunction()
