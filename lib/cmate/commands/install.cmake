list(APPEND CMATE_CMDS "install")
set(CMATE_INSTALL_SHORT_HELP "Install dependencies listed in deps.txt")
set(
    CMATE_INSTALL_HELP
    "
Usage: cmate install

${CMATE_INSTALL_SHORT_HELP}"
)

function(cmate_install_cmake_dep)
    cmate_dep_state_file("configured" CONFIGURED)
    cmate_dep_state_file("built" BUILT)
    cmate_dep_state_file("installed" INSTALLED)

    if(NOT EXISTS ${CONFIGURED})
        cmate_msg("building with: ${ARGV}")

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
                -S ${CMATE_DEP_SOURCE_DIR} -B ${CMATE_DEP_BUILD_DIR}
                ${ARGV}
        )
        cmate_dep_set_state("configured")
    endif()
    if(NOT EXISTS ${BUILT})
        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                --build ${CMATE_DEP_BUILD_DIR}
                --config Release
                --parallel
        )
        cmate_dep_set_state("built")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            CMD
                ${CMAKE_COMMAND}
                --install ${CMATE_DEP_BUILD_DIR}
                --config Release
        )
        cmate_dep_set_state("installed")
    endif()
endfunction()

function(cmate_install_meson_dep)
    cmate_dep_state_file("configured" CONFIGURED)
    cmate_dep_state_file("installed" INSTALLED)
    file(MAKE_DIRECTORY ${CMATE_DEP_BUILD_DIR})

    if(NOT EXISTS ${CONFIGURED})
        cmate_run_prog(
            DIR ${CMATE_DEP_BUILD_DIR}
            CMD
                meson
                --prefix=${CMATE_ENV_DIR}
                --pkg-config-path=${CMATE_ENV_DIR}
                --cmake-prefix-path=${CMATE_ENV_DIR}
                ${ARGV}
                . ${SRCDIR}
        )
        cmate_dep_set_state("configured")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(meson install)
        cmate_dep_set_state("installed")
    endif()
endfunction()

function(cmate_install_autotools_dep)
    cmate_dep_state_file("configured" CONFIGURED)
    cmate_dep_state_file("installed" INSTALLED)
    file(MAKE_DIRECTORY ${CMATE_DEP_BUILD_DIR})

    if(NOT EXISTS ${CONFIGURED})
        cmate_run_prog(
            DIR ${CMATE_DEP_BUILD_DIR}
            CMD
                ${CMATE_DEP_SOURCE_DIR}/configure
                --prefix=${CMATE_ENV_DIR}
                ${ARGV}
        )
        cmate_dep_set_state("configured")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            DIR ${CMATE_DEP_BUILD_DIR}
            CMD make install
        )
        cmate_dep_set_state("installed")
    endif()
endfunction()

function(cmate_install_makefile_dep)
    cmate_dep_state_file("built" BUILT)
    cmate_dep_state_file("installed" INSTALLED)
    file(MAKE_DIRECTORY ${CMATE_DEP_BUILD_DIR})

    if(NOT EXISTS ${BUILT})
        cmate_run_prog(
            DIR ${CMATE_DEP_SOURCE_DIR}
            CMD make
        )
        cmate_dep_set_state("built")
    endif()
    if(NOT EXISTS ${INSTALLED})
        cmate_run_prog(
            DIR ${CMATE_DEP_SOURCE_DIR}
            CMD make prefix=${CMATE_ENV_DIR} install
        )
        cmate_dep_set_state("installed")
    endif()
endfunction()

function(cmate_install_dep ARGS)
    set(OPT_PROC ON)
    string(REGEX MATCHALL "[^ \"']+|\"([^\"]*)\"|'([^']*)'" ARGS "${ARGS}")

    foreach(ARG ${ARGS})
        if(OPT_PROC AND ARG MATCHES "^--")
            if(ARG STREQUAL "--")
                set(OPT_PROC OFF)
            elseif(ARG MATCHES "^--srcdir=(.+)")
                cmate_setg(
                    CMATE_DEP_SOURCE_DIR
                    "${CMATE_DEP_SOURCE_DIR}/${CMAKE_MATCH_1}"
                )
            endif()
        else()
            list(APPEND CONF_ARGS ${ARG})
        endif()
    endforeach()

    if(NOT IS_DIRECTORY "${CMATE_DEP_SOURCE_DIR}")
        cmate_die("invalid source directory: ${CMATE_DEP_SOURCE_DIR}")
    endif()

    if(EXISTS "${CMATE_DEP_SOURCE_DIR}/CMakeLists.txt")
        cmate_install_cmake_dep(${CONF_ARGS})
    elseif(EXISTS "${CMATE_DEP_SOURCE_DIR}/meson.build")
        cmate_install_meson_dep(${CONF_ARGS})
    elseif(EXISTS "${CMATE_DEP_SOURCE_DIR}/configure")
        cmate_install_autotools_dep(${CONF_ARGS})
    elseif(EXISTS "${CMATE_DEP_SOURCE_DIR}/Makefile")
        cmate_install_makefile_dep(${CONF_ARGS})
    else()
        cmate_die("don't know how to build in ${CMATE_DEP_SOURCE_DIR}")
    endif()
endfunction()

function(cmate_install_repo HOST REPO TAG ARGS)
    cmate_dep_get_repo(${HOST} ${REPO} "${TAG}")
    cmate_install_dep("${ARGS}")
endfunction()

function(cmate_install_url URL ARGS)
    cmate_deps_get_url(${URL})
    cmate_install_dep("${ARGS}")
endfunction()

function(cmate_install)
    if(NOT EXISTS ${CMATE_DEPSFILE})
        cmate_msg("no dependencies")
        return()
    endif()

    file(STRINGS ${CMATE_DEPSFILE} DEPS)

    foreach(SPEC ${DEPS})
        if(SPEC MATCHES "^#")
            # Skip comments
            continue()
        elseif(SPEC MATCHES "^([A-Za-z0-9_-]+)=(.+)$")
            # Variable assignment
            cmate_setg("CMATE_${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}")
        elseif(SPEC MATCHES "^([a-z]+://[^ ]+)([ ](.+))?$")
            # URL
            set(URL ${CMAKE_MATCH_1})
            set(ARGS "${CMAKE_MATCH_3}")
            cmate_msg("checking ${URL}")
            cmate_install_url(${URL} "${ARGS}")
        elseif(SPEC MATCHES "^(([^: ]+):)?([^@ ]+)(@([^ ]+))?([ ](.+))?$")
            # GitHub/GitLab style project short ref
            if(CMAKE_MATCH_2)
                if(CMATE_${CMAKE_MATCH_2})
                    set(HOST ${CMATE_${CMAKE_MATCH_2}})
                else()
                    cmate_die("unknown id: ${CMAKE_MATCH_2}")
                endif()
            else()
                set(HOST ${CMATE_${CMATE_GIT_HOST}})
            endif()

            set(REPO ${CMAKE_MATCH_3})
            set(TAG ${CMAKE_MATCH_5})
            set(ARGS "${CMAKE_MATCH_7}")
            cmate_msg("checking ${REPO}")
            cmate_install_repo(${HOST} ${REPO} "${TAG}" "${ARGS}")
        else()
            cmate_die("invalid dependency line: ${SPEC}")
        endif()
    endforeach()
endfunction()
