function(cmate_deps_get_dep_dir DEP VAR)
    string(MD5 HASH "${${DEP}.URL}")
    set(DIR "${CMATE_DL_DIR}/${HASH}")
    set("${VAR}" "${DIR}" PARENT_SCOPE)
endfunction()

function(cmate_deps_get_dep_cache_dir DEP TYPE VAR)
    cmate_deps_get_dep_dir("${DEP}" DIR)
    set("${VAR}" "${DIR}/${TYPE}" PARENT_SCOPE)
endfunction()

function(cmate_deps_get_state_file DEP STATE VAR)
    cmate_deps_get_dep_cache_dir("${DEP}" "state" DIR)
    set(${VAR} "${DIR}/.${STATE}" PARENT_SCOPE)
endfunction()

function(cmate_deps_set_state DEP STATE)
    cmate_deps_get_dep_cache_dir("${DEP}" "state" DIR)
    file(MAKE_DIRECTORY ${DIR})
    cmate_deps_get_state_file("${DEP}" ${STATE} FILE)
    file(TOUCH ${FILE})
endfunction()

function(cmate_deps_get_repo DEP)
    set(HOST "${${DEP}.HOST}")

    if(HOST MATCHES "^\\$\\{(.+)\\}$")
        # Dereference variable
        set(HOST ${${CMAKE_MATCH_1}})
    endif()

    if(HOST STREQUAL "GH")
        set(HOST "https://github.com")
    elseif(TYPE STREQUAL "GL")
        set(HOST "https://gitlab.com")
    endif()

    set(URL "${HOST}/${${DEP}.REPO}.git")

    set(GIT_ARGS "clone")
    list(
        APPEND GIT_ARGS
        -c advice.detachedHead=false
        --depth 1
    )

    if("${${DEP}.REF}")
        list(APPEND GIT_ARGS --branch "${${DEP}.REF}")
    endif()

    cmate_deps_get_dep_cache_dir(${DEP} "sources" SDIR)
    cmate_deps_get_state_file(${DEP} "fetched" FETCHED)

    if(NOT IS_DIRECTORY ${SDIR} OR NOT EXISTS ${FETCHED})
        # Whatever the reason, we're (re-)fetching
        file(REMOVE_RECURSE ${SDIR})
        cmate_info("cloning ${URL} in ${SDIR}")
        cmate_run_prog(CMD git ${GIT_ARGS} ${URL} ${SDIR})
        cmate_deps_set_state(${DEP} "fetched")
    endif()
endfunction()

function(cmate_deps_get_url_filename DEP VAR)
    if("${${DEP}.URL}" MATCHES "/([^/]+)$")
        set(FILE ${CMAKE_MATCH_1})
    else()
        cmate_die("can't find filename from URL: ${${DEP}.URL}")
    endif()

    set(${VAR} "${FILE}" PARENT_SCOPE)
endfunction()

function(cmate_deps_get_url DEP SOURCES_DIR_VAR)
    string(MD5 HASH "${${DEP}.URL}")

    cmate_deps_get_url_filename(${DEP} DFILE)
    cmate_deps_get_state_file("${DEP}" "fetched" FETCHED)
    cmate_deps_get_state_file("${DEP}" "extracted" EXTRACTED)
    cmate_deps_get_dep_dir(${DEP} DDIR)
    cmate_deps_get_dep_cache_dir(${DEP} "sources" DSDIR)

    set(DFILE "${DDIR}/${DFILE}")

    if(NOT EXISTS ${DFILE})
        message("MAKING ${DDIR} for ${DFILE}")
        file(MAKE_DIRECTORY ${DDIR})
        cmate_info("downloading ${URL} in ${DDIR}")
        cmate_download("${${DEP}.URL}" ${DFILE})
        cmate_deps_set_state("${DEP}" "fetched")
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
        cmate_deps_set_state("${DEP}" "extracted")
    endif()

    cmate_unique_dir(${DSDIR} UDIR)
    set(${SOURCES_DIR_VAR} ${UDIR} PARENT_SCOPE)
endfunction()

cmate_setg(CMATE_DEPS_PROPS "TYPE;NAME;URL;HOST;REPO;TAG;ARGS;SRCDIR")

function(cmate_deps_dump_dep DEP)
    foreach(PROP ${CMATE_DEPS_PROPS})
        cmate_msg("DEP.${PROP}=${${DEP}.${PROP}}")
    endforeach()
endfunction()

function(cmate_deps_parse SPEC VAR)
    if(SPEC MATCHES "^([a-z]+://[^ ]+)$")
        # Raw URL, find a name
        cmate_setprop(DEP TYPE "url")
        cmate_setprop(DEP URL ${CMAKE_MATCH_1})
        cmate_deps_get_url_filename(DEP DFILE)
        get_filename_component(NAME ${DFILE} NAME_WE)
        cmate_setprop(DEP NAME ${NAME})
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
        cmate_setprop(DEP TAG "${CMAKE_MATCH_5}")
        cmate_setprop(DEP URL "${DEP.HOST}/${DEP.REPO}.git")
        set("DEP.NAME" ${DEP.REPO})
        string(REGEX REPLACE "[^A-Za-z0-9_]" "_" "DEP.NAME" "${DEP.NAME}")
    else()
        cmate_die("unable to parse dependency: ${SPEC}")
    endif()

    cmate_setprops(${VAR} DEP "${CMATE_DEPS_PROPS}" PARENT_SCOPE)
endfunction()

function(cmate_deps_install_cmake_dep VAR)
    cmate_deps_get_state_file(${VAR} "configured" CONFIGURED)
    cmate_deps_get_state_file(${VAR} "built" BUILT)
    cmate_deps_get_state_file(${VAR} "installed" INSTALLED)

    if(NOT EXISTS ${CONFIGURED})
        cmate_msg("building with: ${DEP.ARGS}")

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
                -S ${CMATE_DEPS_SOURCE_DIR} -B ${CMATE_DEPS_BUILD_DIR}
                ${DEP.ARGS}
        )
        cmate_deps_set_state("configured")
    endif()
    if(NOT EXISTS ${BUILT})
        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                --build ${CMATE_DEPS_BUILD_DIR}
                --config Release
                --parallel
        )
        cmate_deps_set_state("built")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                --install ${CMATE_DEPS_BUILD_DIR}
                --config Release
        )
        cmate_deps_set_state("installed")
    endif()
endfunction()

function(cmate_deps_install_meson_dep)
    cmate_deps_get_state_file("configured" CONFIGURED)
    cmate_deps_get_state_file("installed" INSTALLED)
    file(MAKE_DIRECTORY ${CMATE_DEPS_BUILD_DIR})

    if(NOT EXISTS ${CONFIGURED})
        cmate_run_prog(
            DIR ${CMATE_DEPS_BUILD_DIR}
            CMD
                meson
                --prefix=${CMATE_ENV_DIR}
                --pkg-config-path=${CMATE_ENV_DIR}
                --cmake-prefix-path=${CMATE_ENV_DIR}
                ${DEP.ARGS}
                . ${SRCDIR}
        )
        cmate_deps_set_state("configured")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(meson install)
        cmate_deps_set_state("installed")
    endif()
endfunction()

function(cmate_deps_install_autotools_dep)
    cmate_deps_get_state_file("configured" CONFIGURED)
    cmate_deps_get_state_file("installed" INSTALLED)
    file(MAKE_DIRECTORY ${CMATE_DEPS_BUILD_DIR})

    if(NOT EXISTS ${CONFIGURED})
        cmate_run_prog(
            DIR ${CMATE_DEPS_BUILD_DIR}
            CMD
                ${CMATE_DEPS_SOURCE_DIR}/configure
                --prefix=${CMATE_ENV_DIR}
                ${DEP.ARGS}
        )
        cmate_deps_set_state("configured")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            DIR ${CMATE_DEPS_BUILD_DIR}
            CMD make install
        )
        cmate_deps_set_state("installed")
    endif()
endfunction()

function(cmate_deps_install_makefile_dep)
    cmate_deps_get_state_file("built" BUILT)
    cmate_deps_get_state_file("installed" INSTALLED)
    file(MAKE_DIRECTORY ${CMATE_DEPS_BUILD_DIR})

    if(NOT EXISTS ${BUILT})
        cmate_run_prog(
            DIR ${CMATE_DEPS_SOURCE_DIR}
            CMD make
        )
        cmate_deps_set_state("built")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            DIR ${CMATE_DEPS_SOURCE_DIR}
            CMD make prefix=${CMATE_ENV_DIR} install
        )
        cmate_deps_set_state("installed")
    endif()
endfunction()

function(cmate_deps_install_dep DEP)
    if(NOT "${${DEP}.SRCDIR}" STREQUAL "")
        cmate_setg(
            CMATE_DEPS_SOURCE_DIR
            "${CMATE_DEPS_SOURCE_DIR}/${${VAR}.SRCDIR}"
        )
    endif()

    if(NOT IS_DIRECTORY "${CMATE_DEPS_SOURCE_DIR}")
        cmate_die("invalid source directory: ${CMATE_DEPS_SOURCE_DIR}")
    endif()

    if(EXISTS "${CMATE_DEPS_SOURCE_DIR}/CMakeLists.txt")
        cmate_deps_install_cmake_dep(${VAR})
    elseif(EXISTS "${CMATE_DEPS_SOURCE_DIR}/meson.build")
        cmate_deps_install_meson_dep(${VAR})
    elseif(EXISTS "${CMATE_DEPS_SOURCE_DIR}/configure")
        cmate_deps_install_autotools_dep(${VAR})
    elseif(EXISTS "${CMATE_DEPS_SOURCE_DIR}/Makefile")
        cmate_deps_install_makefile_dep(${VAR})
    else()
        cmate_die("don't know how to build in ${CMATE_DEPS_SOURCE_DIR}")
    endif()
endfunction()

function(cmate_deps_get_dep DEP)
    cmate_deps_dump_dep(${DEP})

    if(NOT "${${DEP}.REPO}" STREQUAL "")
        cmate_msg("checking ${${DEP}.REPO}")
        cmate_deps_get_repo(${DEP})
    elseif(NOT "${${DEP}.URL}" STREQUAL "")
        cmate_msg("checking ${${DEP}.URL}")
        cmate_deps_get_url(${DEP} SDIR)
        cmate_msg("SOURCES ARE IN ${SDIR}")
    else()
        cmate_die("invalid dependency: ${DEP}")
    endif()
endfunction()
