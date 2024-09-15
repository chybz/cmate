function(cmate_die)
    list(JOIN ARGV " " MSGS)
    set(MSG "CMate: error: ${MSGS}")

    if(${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.29)
        message("${MSG}")
        cmake_language(EXIT 1)
    else()
        message(FATAL_ERROR "${MSG}")
    endif()
endfunction()

function(cmate_msg)
    list(JOIN ARGV " " MSGS)
    message("CMate: ${MSGS}")
endfunction()

function(cmate_warn)
    list(JOIN ARGV " " MSGS)
    message(WARNING "CMate: ${MSGS}")
endfunction()

function(cmate_info)
    list(JOIN ARGV " " MSGS)

    if(CMATE_VERBOSE)
        cmate_msg(${MSGS})
    endif()
endfunction()

function(cmate_setg VAR VAL)
    if("$ENV{CMATE_SET_TRACE}")
        message("SET: ${VAR}=\"${VAL}\"")
    endif()

    set(${VAR} "${VAL}" CACHE INTERNAL "${VAR}")
endfunction()

function(cmate_unsetg VAR)
    unset(${VAR} CACHE)
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

function(cmate_sleep DURATION)
    execute_process(COMMAND ${CMAKE_COMMAND} -E sleep ${DURATION})
endfunction()

function(cmate_set_version)
    if("${CMATE_PROJECT.version}" STREQUAL "")
        cmate_warn("using default version: 0.1.0")
        cmate_setg(CMATE_PROJECT.version "0.1.0")
    endif()

    if("${CMATE_PROJECT.version}" MATCHES "^([^\\.]+)\\.([^\\.]+)\\.([^\\.]+)$")
        cmate_setg(CMATE_PROJECT.version_major ${CMAKE_MATCH_1})
        cmate_setg(CMATE_PROJECT.version_minor ${CMAKE_MATCH_2})
        cmate_setg(CMATE_PROJECT.version_patch ${CMAKE_MATCH_3})
    else()
        cmate_die("unable to parse version: ${CMATE_PROJECT.version}")
    endif()
endfunction()

macro(cmate_setv VAR VAL)
    if("${${VAR}}" STREQUAL "")
        set(${VAR} ${VAL})
    endif()
endmacro()

macro(cmate_setprop VAR PROP VAL)
    set("${VAR}.${PROP}" "${VAL}")
endmacro()

macro(cmate_setprops PVAR VAR PROPS)
    set(SINGLE "")
    set(MULTI "")
    cmake_parse_arguments(PROP "PARENT_SCOPE" "${SINGLE}" "${MULTI}" ${ARGN})

    if(PROP_PARENT_SCOPE)
        foreach(PROP ${PROPS})
            set("${PVAR}.${PROP}" "${${VAR}.${PROP}}" PARENT_SCOPE)
        endforeach()
    else()
        foreach(PROP ${PROPS})
            set("${PVAR}.${PROP}" "${${VAR}.${PROP}}")
        endforeach()
    endif()
endmacro()

function(cmate_json_array_to_list JSON VAR)
    set(ITEMS "")
    string(JSON T ERROR_VARIABLE ERR TYPE ${JSON})

    if(T STREQUAL "ARRAY")
        string(JSON N LENGTH ${JSON})

        if(${N} GREATER_EQUAL 1)
            math(EXPR N "${N}-1")

            foreach(I RANGE ${N})
                string(JSON ITEM GET ${JSON} ${I})
                list(APPEND ITEMS ${ITEM})
            endforeach()
        endif()
    else()
        set(ITEMS "${JSON}")
    endif()

    set(${VAR} "${ITEMS}" PARENT_SCOPE)
endfunction()

function(cmate_json_get_array JSON KEY VAR)
    string(JSON VALUES ERROR_VARIABLE ERR GET ${JSON} ${KEY})
    set(ITEMS "")

    if (NOT ERR)
        cmate_json_array_to_list("${VALUES}" ITEMS)
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

function(cmate_split STR SEP VAR)
    set(VALUES "")

    while(STR MATCHES "^([^${SEP}]+)${SEP}(.+)$")
        list(APPEND VALUES "${CMAKE_MATCH_1}")
        set(STR "${CMAKE_MATCH_2}")
    endwhile()

    if(NOT STR STREQUAL "")
        list(APPEND VALUES "${STR}")
    endif()

    set(${VAR} "${VALUES}" PARENT_SCOPE)
endfunction()

function(cmate_split_lines STR VAR)
    set(VALUES "")
    set(SEP "\r\n")

    # REGEX MATCHALL can't match empty strings, so "manual" solution... Yeah...
    while(STR MATCHES "^([^${SEP}]*)[${SEP}](.*)$")
        if(CMAKE_MATCH_1 STREQUAL "")
            list(APPEND VALUES "${CMATE_EMPTY_LINE_MARKER}")
        else()
            list(APPEND VALUES "${CMAKE_MATCH_1}")
        endif()

        set(STR "${CMAKE_MATCH_2}")
    endwhile()

    if(NOT STR STREQUAL "")
        list(APPEND VALUES "${STR}")
    endif()

    set(${VAR} "${VALUES}" PARENT_SCOPE)
endfunction()

macro(cmate_split_conf_path PATH VAR)
    cmate_split("${PATH}" "\\." ${VAR})
endmacro()

function(cmate_conf_get PATH VAR)
    cmate_split_conf_path(${PATH} KEYS)

    if(${ARGC} GREATER 2)
        cmate_json_get_array("${ARGV2}" "${KEYS}" VALUE)
    else()
        cmate_json_get_array("${CMATE_CONF}" "${KEYS}" VALUE)
    endif()

    set(${VAR} "${VALUE}" PARENT_SCOPE)
endfunction()

function(cmate_load_conf FILE)
    set(PKGS "")

    if(NOT EXISTS ${FILE})
        cmate_die("configuration not found: ${FILE}")
    endif()

    cmate_yaml_load(${FILE} CMATE_CONF)
    cmate_setg(CMATE_CONF "${CMATE_CONF}")

    foreach(VNAME "name" "version" "namespace" "std")
        cmate_conf_get(${VNAME} VAL)

        if("${VAL}" STREQUAL "")
            cmate_die("project variable \"${VNAME}\" no set")
        else()
            cmate_setg(CMATE_PROJECT.${VNAME} "${VAL}")
        endif()
    endforeach()

    cmate_set_version()
endfunction()

function(cmate_project_varname NAME VAR)
    string(TOUPPER "${CMATE_PROJECT.name}_${NAME}" VNAME)
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
        return()
    endif()

    set(WAIT_INTERVAL 5)
    set(MAX_RETRIES 10)
    set(RETRIES ${MAX_RETRIES})
    set(RC 1)

    while(RC)
        file(DOWNLOAD ${URL} ${FILE} STATUS ST)

        list(GET ST 0 RC)

        if(RC)
            if(RETRIES)
                math(EXPR RETRIES "${RETRIES} - 1")
                math(EXPR ATTEMPT "${MAX_RETRIES} - ${RETRIES}")
                cmate_warn(
                    "download of ${URL} failed"
                    " (attempt ${ATTEMPT} of ${MAX_RETRIES}"
                    ", retrying in ${WAIT_INTERVAL}s)"
                )
                cmate_sleep(${WAIT_INTERVAL})
            else()
                cmate_die("download of ${URL} failed: ${ST}")
            endif()
        endif()
    endwhile()
endfunction()

function(cmate_set_build_types DEBUGVAR RELEASEVAR DEFAULTS)
    if(CMATE_BUILD_TYPES)
        return()
    endif()

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

function(cmate_github_get_latest REPO PKG VAR)
    set(URL "https://github.com/${REPO}/releases/latest/download/${PKG}")

    set(FILE "${CMATE_DL_DIR}/${PKG}")

    if (NOT EXISTS ${FILE})
        cmate_download(${URL} ${FILE})
    endif()

    set(${VAR} ${FILE} PARENT_SCOPE)
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
            cmate_msg("getting ninja from github")
            cmate_github_get_latest("ninja-build/ninja" "ninja-${NOS}.zip" NZIP)

            file(REMOVE_RECURSE ${TDIR})
            file(ARCHIVE_EXTRACT INPUT ${NZIP} DESTINATION ${TDIR})
            file(COPY_FILE "${TDIR}/${NCMD}" "${CMATE_ENV_BIN_DIR}/${NCMD}")
            file(REMOVE_RECURSE ${TDIR})
            cmate_msg("ninja installed in ${CMATE_ENV_BIN_DIR}")
        endif()

        set(NINJA "${CMATE_ENV_BIN_DIR}/${NCMD}")
    endif()

    cmate_setg(CMATE_NINJA ${NINJA})
endfunction()
