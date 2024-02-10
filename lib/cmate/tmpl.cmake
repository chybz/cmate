function(cmate_tmpl_configure NAME VAR)
    set(VALUE "${${VAR}}")
    set(PRE "")

    if(${ARGC} GREATER 2)
        set(PRE "${ARGV2}")
    endif()

    set(TFILE "${CMATE_TMPL_DIR}/${NAME}")
    string(TOUPPER "CMATE_${NAME}" TVAR)
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
        cmate_die("no template content for '${NAME}'")
    endif()

    string(CONFIGURE "${CONTENT}" CONTENT @ONLY)

    if(VALUE)
        string(APPEND VALUE "${PRE}")
    endif()

    string(APPEND VALUE "${CONTENT}")

    set(${VAR} "${VALUE}" PARENT_SCOPE)
endfunction()
