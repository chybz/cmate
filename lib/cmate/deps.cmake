cmate_setg(
    CMATE_DEPS_PROPS
    "TYPE;NAME;URL;HOST;REPO;REF;ARGS;SRCDIR;EXTRACT_DIR;SOURCE_DIR;BUILD_DIR"
)

macro(cmate_deps_copy_dep TOV FROMV)
    set(SINGLE "")
    set(MULTI "")
    cmake_parse_arguments(ARGS "PARENT_SCOPE" "${SINGLE}" "${MULTI}" ${ARGN})

    if(ARGS_PARENT_SCOPE)
        cmate_setprops(${TOV} ${FROMV} "${CMATE_DEPS_PROPS}" PARENT_SCOPE)
    else()
        cmate_setprops(${TOV} ${FROMV} "${CMATE_DEPS_PROPS}")
    endif()
endmacro()

function(cmate_deps_get_dep_dir DEPV VAR)
    string(MD5 HASH "${${DEPV}.URL}")
    set(DIR "${CMATE_DL_DIR}/${HASH}")
    set("${VAR}" "${DIR}" PARENT_SCOPE)
endfunction()

function(cmate_deps_get_dep_cache_dir DEPV TYPE VAR)
    cmate_deps_get_dep_dir("${DEPV}" DIR)
    set("${VAR}" "${DIR}/${TYPE}" PARENT_SCOPE)
endfunction()

function(cmate_deps_get_state_file DEPV STATE VAR)
    cmate_deps_get_dep_cache_dir("${DEPV}" "state" DIR)
    set(${VAR} "${DIR}/.${STATE}" PARENT_SCOPE)
endfunction()

function(cmate_deps_set_state DEPV STATE)
    cmate_deps_get_dep_cache_dir("${DEPV}" "state" DIR)
    file(MAKE_DIRECTORY ${DIR})
    cmate_deps_get_state_file("${DEPV}" ${STATE} FILE)
    file(TOUCH ${FILE})
endfunction()

function(cmate_deps_check_repo URL)
    set(GIT_ARGS "ls-remote")
    cmate_run_prog(
        MSG "checking remote at ${URL}"
        ERR "invalid remote at ${URL}"
        CMD git ${GIT_ARGS} ${URL}
        QUIET
    )
endfunction()

function(cmate_deps_get_source_dir DEPV VAR)
    set(DIR "${${DEPV}.EXTRACT_DIR}")

    if(NOT "${${DEPV}.SRCDIR}" STREQUAL "")
        set(DIR "${${DEPV}.EXTRACT_DIR}/${${DEPV}.SRCDIR}")
    endif()

    set(${VAR} ${DIR} PARENT_SCOPE)
endfunction()

function(cmate_deps_get_repo DEPV)
    cmate_deps_copy_dep(DEP ${DEPV})

    set(HOST "${DEP.HOST}")

    if(HOST MATCHES "^\\$\\{(.+)\\}$")
        # Dereference variable
        set(HOST ${${CMAKE_MATCH_1}})
    endif()

    if(HOST STREQUAL "GH")
        set(HOST "https://github.com")
    elseif(TYPE STREQUAL "GL")
        set(HOST "https://gitlab.com")
    endif()

    set(URL "${HOST}/${DEP.REPO}.git")

    cmate_deps_check_repo(${URL})

    set(GIT_ARGS "clone")
    list(
        APPEND GIT_ARGS
        -c advice.detachedHead=false
        --depth 1
    )

    if("${DEP.REF}")
        list(APPEND GIT_ARGS --branch "${DEPV.REF}")
    endif()

    cmate_deps_get_dep_cache_dir(DEP "sources" SDIR)
    cmate_deps_get_dep_cache_dir(DEP "build" BDIR)
    cmate_deps_get_state_file(DEP "fetched" FETCHED)

    if(NOT IS_DIRECTORY ${SDIR} OR NOT EXISTS ${FETCHED})
        # Whatever the reason, we're (re-)fetching
        file(REMOVE_RECURSE ${SDIR})
        cmate_info("cloning ${URL} in ${SDIR}")
        cmate_run_prog(CMD git ${GIT_ARGS} ${URL} ${SDIR})
        cmate_deps_set_state(DEP "fetched")
    endif()

    cmate_setprop(DEP EXTRACT_DIR ${SDIR})
    cmate_deps_get_source_dir(DEP SOURCE_DIR)
    cmate_setprop(DEP EXTRACT_DIR ${SDIR})
    cmate_setprop(DEP SOURCE_DIR ${SOURCE_DIR})
    cmate_setprop(DEP BUILD_DIR ${BDIR})

    cmate_deps_copy_dep(${DEPV} DEP PARENT_SCOPE)
endfunction()

function(cmate_deps_get_url_filename DEPV VAR)
    if("${${DEPV}.URL}" MATCHES "/([^/]+)$")
        set(FILE ${CMAKE_MATCH_1})
    else()
        cmate_die("can't find filename from URL: ${${DEPV}.URL}")
    endif()

    set(${VAR} "${FILE}" PARENT_SCOPE)
endfunction()

function(cmate_deps_get_url DEPV)
    cmate_deps_copy_dep(DEP ${DEPV})

    cmate_deps_get_url_filename(${DEPV} DFILE)
    cmate_deps_get_state_file("${DEPV}" "fetched" FETCHED)
    cmate_deps_get_state_file("${DEPV}" "extracted" EXTRACTED)
    cmate_deps_get_dep_dir(${DEPV} DDIR)
    cmate_deps_get_dep_cache_dir(${DEPV} "sources" DSDIR)
    cmate_deps_get_dep_cache_dir(${DEPV} "build" BDIR)

    set(DFILE "${DDIR}/${DFILE}")

    if(NOT EXISTS ${DFILE})
        file(MAKE_DIRECTORY ${DDIR})
        cmate_info("downloading ${URL} in ${DDIR}")
        cmate_download("${${DEPV}.URL}" ${DFILE})
        cmate_deps_set_state("${DEPV}" "fetched")
    else()
    endif()

    if(NOT IS_DIRECTORY ${DSDIR} OR NOT EXISTS ${EXTRACTED})
        file(REMOVE_RECURSE ${DSDIR})
        cmate_info("extracting ${FILE}")
        file(
            ARCHIVE_EXTRACT
            INPUT ${DFILE}
            DESTINATION ${DSDIR}
        )
        cmate_deps_set_state("${DEPV}" "extracted")
    endif()

    cmate_unique_dir(${DSDIR} UDIR)
    cmate_setprop(${DEPV} EXTRACT_DIR ${UDIR})
    cmate_deps_get_source_dir(${DEPV} SOURCE_DIR)
    cmate_setprop(${DEPV} SOURCE_DIR ${SOURCE_DIR})
    cmate_setprop(${DEPV} BUILD_DIR ${BDIR})

    cmate_deps_copy_dep(${DEPV} DEP PARENT_SCOPE)
endfunction()

function(cmate_deps_dump_dep DEPV)
    foreach(PROP ${CMATE_DEPS_PROPS})
        cmate_msg("DEP.${PROP}=${${DEPV}.${PROP}}")
    endforeach()
endfunction()

function(cmate_deps_parse_spec SPEC VAR)
    if(SPEC MATCHES "^([a-z]+)://([^ /]+)/([^ ]+)$")
        message("1=${CMAKE_MATCH_1}")
        message("2=${CMAKE_MATCH_2}")
        message("3=${CMAKE_MATCH_3}")
        set(SCHEME ${CMAKE_MATCH_1})
        set(HOST ${CMAKE_MATCH_2})
        set(REPO ${CMAKE_MATCH_3})

        if(REPO MATCHES "(.+)\\.git(@([^ ]+))?$")
            # Full remote Git URL
            cmate_setprop(DEP TYPE "git")
            cmate_setprop(DEP REPO ${CMAKE_MATCH_1})
            cmate_setprop(DEP REF "${CMAKE_MATCH_3}")
            cmate_setprop(DEP URL "${SCHEME}://${HOST}/${REPO}.git")
        else()
            # Raw URL, find a name
            cmate_setprop(DEP URL ${SPEC})
            cmate_setprop(DEP TYPE "url")
            cmate_deps_get_url_filename(DEP DFILE)
            get_filename_component(NAME ${DFILE} NAME_WE)
            cmate_setprop(DEP NAME ${NAME})
        endif()
    elseif(SPEC MATCHES "^([A-Za-z0-9_]+)@([a-z]+://[^ ]+)$")
        # name@URL
        cmate_setprop(DEP TYPE "url")
        cmate_setprop(DEP NAME ${CMAKE_MATCH_1})
        cmate_setprop(DEP URL ${CMAKE_MATCH_2})
    elseif(SPEC MATCHES "^(([^: ]+):)?([^@ ]+)(@([^ ]+))?$")
        cmate_setprop(DEP TYPE "git")

        # GitHub/GitLab style project short ref
        if(CMAKE_MATCH_2)
            if(CMATE_${CMAKE_MATCH_2})
                cmate_setprop(DEP HOST ${CMATE_${CMAKE_MATCH_2}})
            else()
                cmate_die("unknown id: ${CMAKE_MATCH_2}")
            endif()
        else()
            cmate_setprop(DEP HOST ${CMATE_${CMATE_GIT_HOST}})
        endif()

        cmate_setprop(DEP REPO ${CMAKE_MATCH_3})
        cmate_setprop(DEP REF "${CMAKE_MATCH_5}")
        cmate_setprop(DEP URL "${DEP.HOST}/${DEP.REPO}.git")
        set("DEP.NAME" ${DEP.REPO})
        string(REGEX REPLACE "[^A-Za-z0-9_]" "_" "DEP.NAME" "${DEP.NAME}")
    else()
        cmate_die("unable to parse dependency: ${SPEC}")

    endif()

    cmate_setprops(${VAR} DEP "${CMATE_DEPS_PROPS}" PARENT_SCOPE)
endfunction()

function(cmate_deps_make_dep JSON_SPEC DEPV)
    string(JSON T ERROR_VARIABLE ERR TYPE ${JSON_SPEC})

    if(T STREQUAL "OBJECT")
        string(JSON DKEYS LENGTH ${JSON_SPEC})

        if(NOT DKEYS EQUAL 1)
            cmate_die("invalid dependency: expected a single key, got ${NKEYS}: ${JSON_SPEC}")
        endif()

        string(JSON SPEC MEMBER ${JSON_SPEC} 0)
        cmate_deps_parse_spec(${SPEC} DEP)
        cmate_json_get_array(${JSON_SPEC} "${SPEC};args" DEP.ARGS)
        cmate_json_get_array(${JSON_SPEC} "${SPEC};srcdir" DEP.SRCDIR)
    elseif(T STREQUAL "STRING")
        cmate_deps_parse_spec(${JSON_SPEC} DEP)
    else()
        cmate_die("invalid dependency: expected object or string, got ${JSON_SPEC}")
    endif()

    cmate_setprops(${DEPV} DEP "${CMATE_DEPS_PROPS}" PARENT_SCOPE)
endfunction()

function(cmate_deps_install_cmake_dep DEPV)
    cmate_deps_get_state_file(${DEPV} "configured" CONFIGURED)
    cmate_deps_get_state_file(${DEPV} "built" BUILT)
    cmate_deps_get_state_file(${DEPV} "installed" INSTALLED)

    if(NOT EXISTS ${CONFIGURED})
        cmate_msg("building with: ${${DEPV}.ARGS}")

        set(ARGS "")

        find_program(CMATE_CCACHE ccache)

        if(CMATE_CCACHE)
            list(APPEND ARGS "-DCMAKE_C_COMPILER_LAUNCHER=${CMATE_CCACHE}")
            list(APPEND ARGS "-DCMAKE_CXX_COMPILER_LAUNCHER=${CMATE_CCACHE}")
        endif()

        cmate_check_ninja()

        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                -DCMAKE_PREFIX_PATH=${CMATE_ENV_DIR}
                -DCMAKE_INSTALL_PREFIX=${CMATE_ENV_DIR}
                -DCMAKE_BUILD_TYPE=Release
                -DBUILD_TESTING=OFF
                -G Ninja
                ${ARGS}
                -S ${${DEPV}.SOURCE_DIR} -B ${${DEPV}.BUILD_DIR}
                ${${DEPV}.ARGS}
        )
        cmate_deps_set_state(${DEPV} "configured")
    endif()
    if(NOT EXISTS ${BUILT})
        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                --build ${${DEPV}.BUILD_DIR}
                --config Release
                --parallel
        )
        cmate_deps_set_state(${DEPV} "built")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                --install ${${DEPV}.BUILD_DIR}
                --config Release
        )
        cmate_deps_set_state(${DEPV} "installed")
    endif()
endfunction()

function(cmate_deps_install_meson_dep DEPV)
    cmate_deps_get_state_file(${DEPV} "configured" CONFIGURED)
    cmate_deps_get_state_file(${DEPV} "installed" INSTALLED)
    file(MAKE_DIRECTORY ${${DEPV}.BUILD_DIR})

    if(NOT EXISTS ${CONFIGURED})
        cmate_run_prog(
            DIR ${${DEPV}.BUILD_DIR}
            CMD
                meson
                --prefix=${CMATE_ENV_DIR}
                --pkg-config-path=${CMATE_ENV_DIR}
                --cmake-prefix-path=${CMATE_ENV_DIR}
                ${${DEPV}.ARGS}
                . ${${DEPV}.SOURCE_DIR}
        )
        cmate_deps_set_state(${DEPV} "configured")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(meson install)
        cmate_deps_set_state(${DEPV} "installed")
    endif()
endfunction()

function(cmate_deps_install_autotools_dep DEPV)
    cmate_deps_get_state_file(${DEPV} "configured" CONFIGURED)
    cmate_deps_get_state_file(${DEPV} "installed" INSTALLED)
    file(MAKE_DIRECTORY ${${DEPV}.BUILD_DIR})

    if(NOT EXISTS ${CONFIGURED})
        cmate_run_prog(
            DIR ${${DEPV}.BUILD_DIR}
            CMD
                ${${DEPV}.SOURCE_DIR}/configure
                --prefix=${CMATE_ENV_DIR}
                ${${DEPV}.ARGS}
        )
        cmate_deps_set_state(${DEPV} "configured")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            DIR ${${DEPV}.BUILD_DIR}
            CMD make install
        )
        cmate_deps_set_state(${DEPV} "installed")
    endif()
endfunction()

function(cmate_deps_install_makefile_dep DEPV)
    cmate_deps_get_state_file(${DEPV} "built" BUILT)
    cmate_deps_get_state_file(${DEPV} "installed" INSTALLED)
    file(MAKE_DIRECTORY ${${DEPV}.BUILD_DIR})

    if(NOT EXISTS ${BUILT})
        cmate_run_prog(
            DIR ${${DEPV}.SOURCE_DIR}
            CMD make
        )
        cmate_deps_set_state(${DEPV} "built")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            DIR ${${DEPV}.SOURCE_DIR}
            CMD make prefix=${CMATE_ENV_DIR} install
        )
        cmate_deps_set_state(${DEPV} "installed")
    endif()
endfunction()

function(cmate_deps_install_dep DEPV)
    set(SDIR "${${DEPV}.SOURCE_DIR}")

    if(NOT IS_DIRECTORY "${SDIR}")
        cmate_die("invalid source directory: ${SDIR}")
    endif()

    if(EXISTS "${SDIR}/CMakeLists.txt")
        cmate_deps_install_cmake_dep(${DEPV})
    elseif(EXISTS "${SDIR}/meson.build")
        cmate_deps_install_meson_dep(${DEPV})
    elseif(EXISTS "${SDIR}/configure")
        cmate_deps_install_autotools_dep(${DEPV})
    elseif(EXISTS "${SDIR}/Makefile")
        cmate_deps_install_makefile_dep(${DEPV})
    else()
        cmate_die("don't know how to build in ${SDIR}")
    endif()
endfunction()

function(cmate_deps_get_dep DEPV)
    cmate_deps_copy_dep(DEP ${DEPV})

    if(NOT "${DEP.REPO}" STREQUAL "")
        cmate_msg("checking repository ${DEP.REPO}")
        cmate_deps_get_repo(DEP)
    elseif(NOT "${DEPV.URL}" STREQUAL "")
        cmate_msg("checking url ${DEP.URL}")
        cmate_deps_get_url(DEP)
    else()
        cmate_die("invalid dependency: $DEP")
    endif()

    cmate_deps_copy_dep(${DEPV} DEP PARENT_SCOPE)
endfunction()
