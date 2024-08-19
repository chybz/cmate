list(APPEND CMATE_CMDS "install")
set(CMATE_INSTALL_SHORT_HELP "Install dependencies listed in project.yaml")
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
                -S ${CMATE_DEP_SOURCE_DIR} -B ${CMATE_DEP_BUILD_DIR}
                ${DEP.ARGS}
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
                ${DEP.ARGS}
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
                ${DEP.ARGS}
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

function(cmate_install_dep)
    if(NOT "${DEP.SRCDIR}" STREQUAL "")
        cmate_setg(
            CMATE_DEP_SOURCE_DIR
            "${CMATE_DEP_SOURCE_DIR}/${DEP.SRCDIR}"
        )
    endif()

    if(NOT IS_DIRECTORY "${CMATE_DEP_SOURCE_DIR}")
        cmate_die("invalid source directory: ${CMATE_DEP_SOURCE_DIR}")
    endif()

    if(EXISTS "${CMATE_DEP_SOURCE_DIR}/CMakeLists.txt")
        cmate_install_cmake_dep()
    elseif(EXISTS "${CMATE_DEP_SOURCE_DIR}/meson.build")
        cmate_install_meson_dep()
    elseif(EXISTS "${CMATE_DEP_SOURCE_DIR}/configure")
        cmate_install_autotools_dep()
    elseif(EXISTS "${CMATE_DEP_SOURCE_DIR}/Makefile")
        cmate_install_makefile_dep()
    else()
        cmate_die("don't know how to build in ${CMATE_DEP_SOURCE_DIR}")
    endif()
endfunction()

function(cmate_install)
    cmate_conf_get("deps" DEPS)

    foreach(DEP ${DEPS})
        string(JSON T ERROR_VARIABLE ERR TYPE ${DEP})

        if(T STREQUAL "OBJECT")
            string(JSON DKEYS LENGTH ${DEP})

            if(NOT DKEYS EQUAL 1)
                cmate_die("invalid dependency: expected a single key, got ${NKEYS}: ${DEP}")
            endif()

            string(JSON SPEC MEMBER ${DEP} 0)
            cmate_dep_parse(${SPEC} DEP)
            cmate_json_get_array(${DEP} "${SPEC};args" DEP.ARGS)
            cmate_json_get_array(${DEP} "${SPEC};srcdir" DEP.SRCDIR)
        elseif(T STREQUAL "STRING")
            cmate_dep_parse(${DEP} DEP)
        else()
            cmate_die("invalid dependency: expected object or string, got ${DEP}")
        endif()

        if(NOT "${DEP.REPO}" STREQUAL "")
            cmate_msg("checking ${DEP.REPO}")
            cmate_dep_get_repo(${DEP.HOST} ${DEP.REPO} "${DEP.TAG}")
        elseif(NOT "${DEP.URL}" STREQUAL "")
            cmate_msg("checking ${DEP.URL}")
            cmate_dep_get_url(${DEP.URL})
        else()
            cmate_die("invalid dependency: ${DEP}")
        endif()

        cmate_install_dep()
    endforeach()
endfunction()
