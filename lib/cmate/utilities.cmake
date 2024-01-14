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

function(cmate_load_conf FILE)
    set(PKGS "")

    if(EXISTS ${FILE})
        file(READ ${FILE} JSON)

        string(JSON PROJECT GET ${JSON} "name")
        cmate_setg(CMATE_PROJECT_NAME ${PROJECT})
        string(JSON VERSION GET ${JSON} "version")
        cmate_setg(CMATE_PROJECT_VERSION "${VERSION}")
        cmate_set_version()
        string(JSON NAMESPACE GET ${JSON} "namespace")
        cmate_setg(CMATE_PROJECT_NAMESPACE ${NAMESPACE})

        string(JSON PKGS GET ${JSON} "packages")
    endif()

    cmate_setg(CMATE_PACKAGES "${PKGS}")
endfunction()

function(cmate_run_prog)
    cmake_parse_arguments(RUN "" "DIR" "CMD" ${ARGN})

    if(CMATE_SIMULATE)
        list(PREPEND RUN_CMD "echo")
    endif()

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

function(cmate_set_build_type RELEASE_FLAG_VAR)
    if(CMATE_BUILD_DIR)
        return()
    endif()

    if(${RELEASE_FLAG_VAR})
        set(TYPE "Release")
    else()
        set(TYPE "Debug")
    endif()

    string(TOLOWER ${TYPE} TDIR)
    cmate_setg(CMATE_BUILD_DIR "${CMATE_BUILD_BASE_DIR}/${TDIR}")
endfunction()

function(cmate_github_get_latest REPO VAR RE)
    set(URL "https://api.github.com/repos/${REPO}/releases/latest")
    set(TDIR "${CMATE_TMP_DIR}/${REPO}")
    set(INFO "${TDIR}/info.json")

    if (NOT EXISTS ${INFO})
        file(MAKE_DIRECTORY ${TDIR})
        cmate_msg("NINJA: dl ${URL} to ${INFO}")
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
            return()
        endif()
    endforeach()
endfunction()

function(cmate_check_ninja)
    find_program(CMATE_NINJA ninja)

    if(CMATE_NINJA)
        cmate_msg("ninja found at ${CMATE_NINJA}")
    else()
        set(NOS "")

        if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
            set(NOS "linux")
        elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
            set(NOS "win")
        elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
            set(NOS "mac")
        else()
            cmate_die("unsupported ninja for ${CMAKE_SYSTEM_NAME}")
        endif()

        cmate_github_get_latest("ninja-build/ninja" NZIP "ninja-${NOS}.zip$")
    endif()
endfunction()
