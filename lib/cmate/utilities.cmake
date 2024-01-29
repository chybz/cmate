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
    if("$ENV{CMATE_SET_TRACE}")
        message("SET: ${VAR}=\"${VAL}\"")
    endif()

    set(${VAR} "${VAL}" CACHE INTERNAL "${VAR}")
endfunction()

function(cmate_appendg VAR VAL)
    if(${VAR})
        set(VAL "${${VAR}};${VAL}")
    endif()

    cmate_setg(${VAR} "${VAL}")
endfunction()

function(cmate_setgdir VAR VAL)
    cmate_setg(${VAR} "${VAL}")
    file(MAKE_DIRECTORY ${${VAR}})
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

    if("${CMATE_PROJECT_VERSION}" STREQUAL "")
        cmate_warn("using default version: 0.1.0")
        cmate_setg(CMATE_PROJECT_VERSION "0.1.0")
    endif()

    if("${CMATE_PROJECT_VERSION}" MATCHES "^([^\\.]+)\\.([^\\.]+)\\.([^\\.]+)$")
        cmate_setg(CMATE_PROJECT_VERSION_MAJOR ${CMAKE_MATCH_1})
        cmate_setg(CMATE_PROJECT_VERSION_MINOR ${CMAKE_MATCH_2})
        cmate_setg(CMATE_PROJECT_VERSION_PATCH ${CMAKE_MATCH_3})
    else()
        cmate_die("unable to parse version: ${CMATE_PROJECT_VERSION}")
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

function(cmate_json_set_array JVAR JSON KEY VAR)
    set(ARRAY "[]")
    set(I 0)

    foreach(ITEM ${VAR})
        string(JSON ARRAY SET "${ARRAY}" "${I}" "\"${ITEM}\"")
        math(EXPR I "${I}+1")
    endforeach()

    string(JSON JSON SET ${JSON} ${KEY} ${ARRAY})
    set(${JVAR} ${JSON} PARENT_SCOPE)
endfunction()

function(cmate_json_get_str JSON KEY VAR DEF)
    string(JSON STR ERROR_VARIABLE ERR GET ${JSON} ${KEY})

    if(ERR)
        set(STR ${DEF})
    endif()

    set(${VAR} ${STR} PARENT_SCOPE)
endfunction()

function(cmate_load_conf FILE)
    set(PKGS "")
    set(JSON "{}")

    if(EXISTS ${FILE})
        file(READ ${FILE} JSON)
    endif()

    foreach(VNAME "name" "version" "namespace")
        set(VAR "CMATE_PROJECT_${VNAME}")
        string(TOUPPER ${VAR} VAR)

        cmate_json_get_str(${JSON} ${VNAME} ${VAR} "")

        if("${${VAR}}" STREQUAL "")
            cmate_die("project variable \"${VNAME}\" no set")
        else()
            cmate_setg(${VAR} ${${VAR}})
        endif()
    endforeach()

    cmate_set_version()
endfunction()

function(cmate_project_varname NAME VAR)
    string(TOUPPER "${CMATE_PROJECT_NAME}_${NAME}" VNAME)
    string(REPLACE "-" "_" VNAME ${VNAME})
    set(${VAR} ${VNAME} PARENT_SCOPE)
endfunction()

function(cmate_join_escape_list LVAR OVAR)
    list(JOIN ${LVAR} "_semicolon_" ESCAPED)
    set(${OVAR} ${ESCAPED} PARENT_SCOPE)
endfunction()

macro(cmate_unescape_list LVAR)
    list(TRANSFORM ${LVAR} REPLACE "_semicolon_" "\\\;")
endmacro()

function(cmate_unquote STR VAR)
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

function(cmate_run_prog)
    cmake_parse_arguments(RUN "" "DIR" "CMD" ${ARGN})

    cmate_unescape_list(RUN_CMD)

    execute_process(
        COMMAND ${RUN_CMD}
        WORKING_DIRECTORY "${RUN_DIR}"
        RESULTS_VARIABLE RC
    )

    if(RC)
        list(JOIN ARGV " " RUN_CMD)
        cmate_die("command failed: ${RUN_CMD}")
    endif()
endfunction()

function(cmate_unique_dir PATH VAR)
    file(GLOB PATHS "${PATH}/*")

    foreach(PATH ${PATHS})
        if(IS_DIRECTORY ${PATH})
            list(APPEND ALL_DIRS ${PATH})
        endif()
    endforeach()

    list(LENGTH ALL_DIRS DIRS)

    if(DIRS EQUAL 0)
        cmate_die("no directories found in ${PATH}")
    elseif(DIRS GREATER 1)
        cmate_die("multiple directories found ${PATH}")
    endif()

    list(GET ALL_DIRS 0 DIR)
    set(${VAR} ${DIR} PARENT_SCOPE)
endfunction()

function(cmate_download URL FILE)
    if(CMATE_SIMULATE)
        cmate_msg("download ${URL} to ${FILE}")
    else()
        file(DOWNLOAD ${URL} ${FILE} STATUS ST)
    endif()

    list(GET ST 0 RC)

    if(RC)
        cmate_die("download of ${URL} failed: ${ST}")
    endif()
endfunction()

function(cmate_set_build_types DEBUGVAR RELEASEVAR DEFAULTS)
    set(TYPES "")

    if(NOT "${${DEBUGVAR}}" AND NOT "${${RELEASEVAR}}")
        set(TYPES ${DEFAULTS})
    else()
        foreach(TYPE "Debug" "Release")
            string(TOUPPER "${TYPE}VAR" TVAR)
            set(TVAR "${${TVAR}}")

            if("${${TVAR}}")
                list(APPEND TYPES "${TYPE}")
            endif()
        endforeach()
    endif()

    cmate_setg(CMATE_BUILD_TYPES "${TYPES}")
endfunction()

function(cmate_github_get_latest REPO VAR RE)
    set(URL "https://api.github.com/repos/${REPO}/releases/latest")
    set(TDIR "${CMATE_TMP_DIR}/${REPO}")
    set(INFO "${TDIR}/info.json")

    if (NOT EXISTS ${INFO})
        file(MAKE_DIRECTORY ${TDIR})
        cmate_download(${URL} ${INFO})
    endif()

    file(READ ${INFO} VINFO)
    cmate_json_get_array(${VINFO} "assets" ASSETS)

    foreach(ASSET ${ASSETS})
        string(
            JSON
            BDURL
            ERROR_VARIABLE ERR
            GET "${ASSET}" "browser_download_url"
        )

        if(NOT ERR AND ${BDURL} MATCHES ${RE})
            string(JSON FILE GET "${ASSET}" "name")
            set(FILE "${CMATE_DL_DIR}/${FILE}")

            if (NOT EXISTS ${FILE})
                cmate_download(${BDURL} ${FILE})
            endif()

            set(${VAR} ${FILE} PARENT_SCOPE)
            break()
        endif()
    endforeach()

    file(REMOVE_RECURSE ${TDIR})
endfunction()

function(cmate_check_ninja)
    if(CMATE_NO_NINJA)
        unset(CMATE_NINJA)
        return()
    endif()

    find_program(NINJA ninja)
    set(TDIR "${CMATE_TMP_DIR}/ninja")

    if(NOT NINJA)
        set(NOS "")
        set(NCMD "ninja")

        if(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Linux")
            set(NOS "linux")
        elseif(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
            set(NOS "win")
            set(NCMD "ninja.exe")
        elseif(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Darwin")
            set(NOS "mac")
        else()
            cmate_die("Please install ninja: ${CMAKE_SYSTEM_NAME}")
        endif()

        if(NOT EXISTS "${CMATE_ENV_BIN_DIR}/${NCMD}")
            cmate_github_get_latest(
                "ninja-build/ninja"
                NZIP
                "ninja-${NOS}.zip$"
            )

            file(REMOVE_RECURSE ${TDIR})
            file(ARCHIVE_EXTRACT INPUT ${NZIP} DESTINATION ${TDIR})
            file(COPY_FILE "${TDIR}/${NCMD}" "${CMATE_ENV_BIN_DIR}/${NCMD}")
            file(REMOVE_RECURSE ${TDIR})
        endif()

        set(NINJA "${CMATE_ENV_BIN_DIR}/${NCMD}")
    endif()

    cmate_setg(CMATE_NINJA ${NINJA})
endfunction()
