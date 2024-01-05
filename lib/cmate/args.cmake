function(cmate_check_option OPT OPTS LABEL)
    list(FIND OPTS ${OPT} IDX)

    if (IDX LESS 0)
        cmate_die("unknown ${LABEL} option: ${OPT}")
    endif()
endfunction()

function(cmate_locate_cmate_arguments)
    set(FOUND OFF)

    foreach(POS RANGE ${CMAKE_ARGC})
        string(TOLOWER "${CMAKE_ARGV${POS}}" ARG)
        math(EXPR POS "${POS}+1")

        if (ARG MATCHES "${CMATE}$")
            # Script args follow us, POS already incremented
            set(FOUND ON)
            cmate_setg(CMATE_POS ${POS})
            break()
        endif()
    endforeach()

    if(NOT FOUND)
        # Should not happen if script has correct name (see CMATE at top)
        cmate_die("parse_argument")
    endif()
endfunction()

function(cmate_parse_arguments)
    cmate_locate_cmate_arguments()
    set(OPTS_LABEL "generic")
    set(OPTS ${CMATE_OPTIONS})

    while(CMATE_POS LESS ${CMAKE_ARGC})
        if ("${CMAKE_ARGV${CMATE_POS}}" MATCHES "^--?([A-Za-z0-9_-]+)(=(.+))?$")
            #cmate_check_option(${CMAKE_MATCH_1} "${OPTS}" ${OPTS_LABEL})
            set(OPT "CMATE")

            if(CMATE_CMD)
                string(APPEND OPT "_${CMATE_CMD}")
            endif()

            string(APPEND OPT "_${CMAKE_MATCH_1}")
            string(REPLACE "-" "_" OPT "${OPT}")
            string(TOUPPER ${OPT} OPT)

            if("${CMAKE_MATCH_3}" STREQUAL "")
                cmate_setg(${OPT} 1)
            else()
                cmate_setg(${OPT} "${CMAKE_MATCH_3}")
            endif()
        elseif("${CMATE_CMD}" STREQUAL "")
            set(CMATE_CMD "${CMAKE_ARGV${CMATE_POS}}")
            set(OPTS_LABEL ${CMATE_CMD})
            set(OPTS_VAR CMATE_${CMATE_CMD}_OPTIONS)
            string(TOUPPER "${OPTS_VAR}" OPTS_VAR)
            set(OPTS ${${OPTS_VAR}})
        else()
            list(APPEND CMATE_ARGS "${CMAKE_ARGV${CMATE_POS}}")
        endif()

        math(EXPR CMATE_POS "${CMATE_POS}+1")
    endwhile()

    list(LENGTH CMATE_ARGS CMATE_ARGC)

    cmate_setg(CMATE_CMD "${CMATE_CMD}")
    cmate_setg(CMATE_ARGS "${CMATE_ARGS}")
    cmate_setg(CMATE_ARGC ${CMATE_ARGC})
    get_filename_component(CMATE_ENV "${CMATE_ENV}" REALPATH)
    cmate_setg(CMATE_ENV ${CMATE_ENV})
endfunction()
