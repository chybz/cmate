function(cmate_die MSG)
    message(FATAL_ERROR "CMate: error: ${MSG}")
endfunction()

function(cmate_msg)
    list(JOIN ARGV "" MSGS)
    message("CMate: ${MSGS}")
endfunction()

function(cmate_warn MSG)
    message(WARNING "CMate: ${MSG}")
endfunction()

function(cmate_info MSG)
    if(CMATE_VERBOSE)
        cmate_msg(${MSG})
    endif()
endfunction()

function(cmate_setg VAR VAL)
    set(${VAR} "${VAL}" CACHE INTERNAL "${VAR}")
endfunction()

function(cmate_state_file STATE VAR)
    set(${VAR} "${CMATE_STATE_DIR}/.${STATE}" PARENT_SCOPE)
endfunction()

function(cmate_clear_state STATE)
    file(MAKE_DIRECTORY ${CMATE_STATE_DIR})
    cmate_state_file(${STATE} FILE)
    file(REMOVE ${FILE})
endfunction()

function(cmate_set_state STATE)
    file(MAKE_DIRECTORY ${CMATE_STATE_DIR})
    cmate_state_file(${STATE} FILE)
    file(TOUCH ${FILE})
endfunction()

function(cmate_clear_states)
    if (IS_DIRECTORY ${CMATE_STATE_DIR})
        file(REMOVE_RECURSE ${CMATE_STATE_DIR})
    endif()
endfunction()

function(cmate_load_version)
    if(NOT "${CMATE_VERSION}" STREQUAL "")
        return()
    endif()

    if("${CMATE_VERSION_FILE}" STREQUAL "")
        cmate_setg(
            CMATE_VERSION_FILE
            "${CMATE_ROOT_DIR}/version.txt"
        )
    endif()

    if(EXISTS ${CMATE_VERSION_FILE})
        file(
            STRINGS ${CMATE_VERSION_FILE} VER
            REGEX "^[^\\.]+\\.[^\\.]+\\.[^\\.]+$"
            LIMIT_COUNT 1
        )

        cmate_setg(CMATE_VERSION ${VER})
    endif()
endfunction()

function(cmate_set_version)
    cmate_load_version()

    if("${CMATE_VERSION}" STREQUAL "")
        cmate_warn("using default version: 0.1.0")
        cmate_setg(CMATE_VERSION "0.1.0")
    endif()

    if("${CMATE_VERSION}" MATCHES "^([^\\.]+)\\.([^\\.]+)\\.([^\\.]+)$")
        cmate_setg(CMATE_VERSION_MAJOR ${CMAKE_MATCH_1})
        cmate_setg(CMATE_VERSION_MINOR ${CMAKE_MATCH_2})
        cmate_setg(CMATE_VERSION_PATCH ${CMAKE_MATCH_3})
    else()
        cmate_die("unable to parse version: ${CMATE_VERSION}")
    endif()
endfunction()

macro(cmate_setv VAR VAL)
    if("${${VAR}}" STREQUAL "")
        set(${VAR} ${VAL})
    endif()
endmacro()

function(cmate_json_get_array JSON KEY VAR)
    string(JSON ARRAY ERROR_VARIABLE ERR GET ${JSON} ${KEY})
    set(ITEMS "")

    if (NOT ERR)
        string(JSON N LENGTH ${ARRAY})

        if(${N} GREATER_EQUAL 1)
            math(EXPR N "${N}-1")

            foreach(I RANGE ${N})
                string(JSON ITEM GET ${ARRAY} ${I})
                list(APPEND ITEMS ${ITEM})
            endforeach()
        endif()
    endif()

    set(${VAR} ${ITEMS} PARENT_SCOPE)
endfunction()

function(cmate_load_conf FILE)
    set(PKGS "")

    if(EXISTS ${FILE})
        file(READ ${FILE} JSON)

        string(JSON PROJECT GET ${JSON} "name")
        cmate_setg(CMATE_PROJECT ${PROJECT})
        string(JSON VERSION GET ${JSON} "version")
        cmate_setg(CMATE_VERSION ${VERSION})
        string(JSON NAMESPACE GET ${JSON} "namespace")
        cmate_setg(CMATE_NAMESPACE ${NAMESPACE})

        string(JSON PKGS GET ${JSON} "packages")
    endif()

    cmate_setg(CMATE_PACKAGES "${PKGS}")
endfunction()
