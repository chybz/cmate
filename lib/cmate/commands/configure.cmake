list(APPEND CMATE_CMDS "configure")
list(
    APPEND
    CMATE_CONFIGURE_OPTIONS
    "dry-run"
    "dump"
    "namespace"
    "version"
    "version-file"
    "source-pat"
    "header-pat"
)
set(CMATE_CONFIGURE_SHORT_HELP "Configure local project")
set(
    CMATE_CONFIGURE_HELP
    "
Usage: cmate configure [OPTIONS]

${CMATE_CONFIGURE_SHORT_HELP}

Options:
  --toolchain=FILE       CMake toolchain file
  --namespace=NS         CMake package namespace
  --version=SEMVER       CMake package version
  --version-file=FILE    CMake package version from FILE
  --version-file=FILE    CMake package version from FILE
  --source-pat=PATTERN   CMate targets source file glob pattern
                         (default: \$CACHE{CMATE_SOURCE_PAT})
  --header-pat=PATTERN   CMate targets header file glob pattern
                         (default: \$CACHE{CMATE_HEADER_PAT})"
)

function(cmate_configure_lib NAME TBASE INC_BASE SRC_BASE)
    string(TOUPPER ${TBASE} VBASE)

    if(${CMATE_DRY_RUN})
        cmate_msg(
            "found library ${NAME}"
            " (I:${INC_BASE}/${NAME}"
            ", S:${SRC_BASE}/${NAME})"
        )
        return()
    endif()

    list(APPEND CMATE_TARGETS ${TBASE})

    set(HDIR "${CMATE_ROOT_DIR}/${INC_BASE}/${NAME}")
    set(SDIR "${CMATE_ROOT_DIR}/${SRC_BASE}/${NAME}")
    set(CM_FILE "${SDIR}/CMakeLists.txt")
    set(LINK_FILE "${SDIR}/${CMATE_LINKFILE}")

    file(GLOB_RECURSE HEADERS "${HDIR}/${CMATE_HEADER_PAT}")
    file(GLOB_RECURSE SOURCES "${SDIR}/${CMATE_SOURCE_PAT}")

    string(APPEND CONTENT "add_library(${TBASE})\n")

    if(CMATE_PROJECT_NAMESPACE)
        string(
            APPEND
            CONTENT
            "add_library(${CMATE_PROJECT_NAMESPACE}::${NAME} ALIAS ${TBASE})\n"
        )
    endif()

    string(
        APPEND
        CONTENT
        "
set(${VBASE}_INC_DIR \"\${PROJECT_SOURCE_DIR}/${INC_BASE}/${NAME}\")
file(GLOB_RECURSE ${VBASE}_HEADERS \${${VBASE}_INC_DIR}/${CMATE_HEADER_PAT})
list(APPEND ${VBASE}_ALL_SOURCES \${${VBASE}_HEADERS})

set(${VBASE}_SRC_DIR \"\${CMAKE_CURRENT_SOURCE_DIR}\")
file(GLOB_RECURSE ${VBASE}_SOURCES \${${VBASE}_SRC_DIR}/${CMATE_SOURCE_PAT})
list(APPEND ${VBASE}_ALL_SOURCES \${${VBASE}_SOURCES})

target_sources(
    ${TBASE}
    PRIVATE
        \${${VBASE}_ALL_SOURCES}
)

target_include_directories(
    ${TBASE}
    PUBLIC
        $<BUILD_INTERFACE:\${${VBASE}_INC_DIR}>
        $<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}/${CMATE_PROJECT_NAMESPACE}>
    PRIVATE
        \${CMAKE_CURRENT_SOURCE_DIR}
)
"
    )

    cmate_target_link_deps(${TBASE} ${LINK_FILE} DEPS)
    string(APPEND CONTENT ${DEPS})

    string(
        APPEND
        CONTENT
        "
set_target_properties(
    ${TBASE}
    PROPERTIES
        VERSION ${CMATE_PROJECT_VERSION}
        SOVERSION ${CMATE_PROJECT_VERSION_MAJOR}.${CMATE_PROJECT_VERSION_MINOR}
        EXPORT_NAME ${NAME}
        OUTPUT_NAME ${CMATE_PROJECT_NAMESPACE}_${NAME}
)
"
    )

    if(${CMATE_DUMP})
        message(${CONTENT})
    endif()

    file(WRITE ${CM_FILE} ${CONTENT})
endfunction()

function(cmate_configure_prog TYPE NAME TBASE SRC_BASE)
    string(TOUPPER ${TBASE} VBASE)

    if(${CMATE_DRY_RUN})
        cmate_msg("found ${TYPE} ${NAME} (${SRC_BASE}/${NAME})")
        return()
    endif()

    set(SDIR "${CMATE_ROOT_DIR}/${SRC_BASE}/${NAME}")
    set(CM_FILE "${SDIR}/CMakeLists.txt")
    set(LINK_FILE "${SDIR}/${CMATE_LINKFILE}")
    file(GLOB_RECURSE SOURCES "${SDIR}/${CMATE_SOURCE_PAT}")

    string(APPEND CONTENT "add_${TYPE}(${TBASE})\n")

    string(
        APPEND
        CONTENT
        "
set(${VBASE}_SRC_DIR \"\${CMAKE_CURRENT_SOURCE_DIR}\")
file(GLOB_RECURSE ${VBASE}_SOURCES \${${VBASE}_SRC_DIR}/${CMATE_SOURCE_PAT})
list(APPEND ${VBASE}_ALL_SOURCES \${${VBASE}_SOURCES})

target_sources(
    ${TBASE}
    PRIVATE
        \${${VBASE}_ALL_SOURCES}
)

target_include_directories(
    ${TBASE}
    PRIVATE
        \${CMAKE_CURRENT_SOURCE_DIR}
)
"
    )

    cmate_target_link_deps(${TBASE} ${LINK_FILE} DEPS)
    string(APPEND CONTENT ${DEPS})

    string(
        APPEND
        CONTENT
        "
set_target_properties(
    ${TBASE}
    PROPERTIES
        OUTPUT_NAME ${NAME}
)
"
    )

    if(${CMATE_DUMP})
        message(${CONTENT})
    endif()

    file(WRITE ${CM_FILE} ${CONTENT})
endfunction()

function(cmate_configure_bin NAME TBASE SRC_BASE)
    cmate_configure_prog("executable" ${NAME} ${TBASE} ${SRC_BASE})
endfunction()

function(cmate_configure_test NAME TBASE SRC_BASE)
    cmate_configure_prog("test" ${NAME} ${TBASE} ${SRC_BASE})
endfunction()

function(cmate_configure_project_packages VAR)
    # CMake style packages
    cmate_load_cmake_package_deps("${CMATE_PACKAGES}" "PRJ")
    set(CONTENT "")

    if(PRJ_CMAKE_PACKAGES)
        string(APPEND CONTENT "\n")
    endif()

    foreach(PKG ${PRJ_CMAKE_PACKAGES})
        if(PRJ_CMAKE_${PKG}_COMPS)
            string(
                APPEND
                CONTENT
            "find_package(
    ${PKG} CONFIG REQUIRED
    COMPONENTS
"
            )

            foreach(PC ${PRJ_CMAKE_${PKG}_COMPS})
                string(APPEND CONTENT "        ${PC}\n")
            endforeach()

            string(APPEND CONTENT ")\n")
        else()
            string(APPEND CONTENT "find_package(${PKG} CONFIG REQUIRED)\n")
        endif()
    endforeach()

    # PkgConfig style packages
    cmate_load_pkgconfig_package_deps("${CMATE_PACKAGES}" "PRJ")

    if(PRJ_PKGCONFIG_PACKAGES)
        string(APPEND CONTENT "find_package(PkgConfig REQUIRED)\n")
    endif()

    foreach(PKG ${PRJ_PKGCONFIG_PACKAGES})
        string(
            APPEND
            CONTENT
            "pkg_check_modules(${PKG} REQUIRED IMPORTED_TARGET ${PKG})\n"
        )
    endforeach()

    set(${VAR} ${CONTENT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project TARGETS SUBDIRS)
    if(${CMATE_DRY_RUN})
        return()
    endif()

    set(CM_FILE "${CMATE_ROOT_DIR}/CMakeLists.txt")

    string(
        APPEND
        CONTENT
        "cmake_minimum_required(VERSION 3.12 FATAL_ERROR)

project(${CMATE_PROJECT_NAME} VERSION ${CMATE_PROJECT_VERSION} LANGUAGES C CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if (CMAKE_CXX_COMPILER_ID STREQUAL \"MSVC\")
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS)
endif()
"
    )

    cmate_configure_project_packages(PKGS)

    if(PKGS)
        string(APPEND CONTENT "${PKGS}")
    endif()

    # Target subdirs
    if(SUBDIRS)
        string(APPEND CONTENT "\n")

        foreach(SUBDIR ${SUBDIRS})
            string(APPEND CONTENT "add_subdirectory(${SUBDIR})\n")
        endforeach()
    endif()

    string(
        APPEND
        CONTENT
        "
install(
    TARGETS"
    )

    foreach(TARGET ${TARGETS})
        string(APPEND CONTENT "\n        ${TARGET}")
    endforeach()

    string(
        APPEND
        CONTENT
        "
    EXPORT ${CMATE_PROJECT_NAME}-config
    RUNTIME DESTINATION \${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION \${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION \${CMAKE_INSTALL_LIBDIR}
)

install(
    EXPORT ${CMATE_PROJECT_NAME}-config
    FILE ${CMATE_PROJECT_NAME}-config.cmake
    NAMESPACE ${CMATE_PROJECT_NAMESPACE}::
    DESTINATION \${CMAKE_INSTALL_LIBDIR}/cmake/${CMATE_PROJECT_NAME}
)
"
    )

    if (IS_DIRECTORY "${CMATE_ROOT_DIR}/include")
        foreach(LIB ${CMATE_LIBS})
            string(
                APPEND
                CONTENT
                "
install(
    DIRECTORY \"\${PROJECT_SOURCE_DIR}/include/${LIB}/\"
    DESTINATION \${CMAKE_INSTALL_INCLUDEDIR}/${CMATE_PROJECT_NAMESPACE}
)
"
            )
        endforeach()
    endif()

    file(WRITE ${CM_FILE} ${CONTENT})
endfunction()

function(cmate_configure_generate)
    # Find libraries (libraries have headers)
    file(GLOB LIB_INC_DIRS "${CMATE_ROOT_DIR}/include/*")
    set(TARGETS "")
    set(LIBS "")
    set(SUBDIRS "")

    foreach(LIB_INC_DIR ${LIB_INC_DIRS})
        string(REPLACE "${CMATE_ROOT_DIR}/include/" "" NAME ${LIB_INC_DIR})
        cmate_target_name(${NAME} "lib" "TNAME")
        cmate_configure_lib(${NAME} ${TNAME} "include" "src/lib")
        list(APPEND TARGETS ${TNAME})
        list(APPEND LIBS ${NAME})
        list(APPEND SUBDIRS "src/lib/${NAME}")
    endforeach()

    cmate_setg(CMATE_LIBS "${LIBS}")

    # Binaries and tests
    foreach(TYPE bin test)
        file(GLOB SRC_DIRS "${CMATE_ROOT_DIR}/src/${TYPE}/*")

        foreach(SRC_DIR ${SRC_DIRS})
            string(REPLACE "${CMATE_ROOT_DIR}/src/${TYPE}/" "" NAME ${SRC_DIR})
            cmate_target_name(${NAME} ${TYPE} "TNAME")
            cmake_language(
                CALL "cmate_configure_${TYPE}"
                ${NAME} ${TNAME} "src/${TYPE}"
            )

            if(NOT "${TYPE}" STREQUAL "test")
                list(APPEND TARGETS ${TNAME})
            endif()

            list(APPEND SUBDIRS "src/${TYPE}/${NAME}")
        endforeach()
    endforeach()

    # Top-level project
    cmate_configure_project("${TARGETS}" "${SUBDIRS}")
endfunction()

function(cmate_configure_cmake_common_args VAR)
    set(ARGS "")

    if (EXISTS "${CMATE_ENV_DIR}")
        list(APPEND ARGS "-DCMAKE_PREFIX_PATH=${CMATE_ENV_DIR}")
    endif()

    list(APPEND ARGS "-DCMAKE_INSTALL_PREFIX=${CMATE_ROOT_DIR}/stage")

    find_program(CMATE_CCACHE ccache)

    if(CMATE_CCACHE)
        list(APPEND ARGS "-DCMAKE_C_COMPILER_LAUNCHER=${CMATE_CCACHE}")
        list(APPEND ARGS "-DCMAKE_CXX_COMPILER_LAUNCHER=${CMATE_CCACHE}")
    endif()

    set(${VAR} ${ARGS} PARENT_SCOPE)
endfunction()

function(cmate_configure_run_cmake_multi)
    cmate_configure_cmake_common_args(ARGS)

    cmate_join_escape_list(CMATE_BUILD_TYPES TYPES)

    list(APPEND ARGS "-DCMAKE_CONFIGURATION_TYPES=${TYPES}")
    list(APPEND ARGS "-S" "${CMATE_ROOT_DIR}")
    list(APPEND ARGS "-B" "${CMATE_BUILD_DIR}")

    if(CMATE_NINJA)
        list(APPEND ARGS "-G" "Ninja Multi-Config")
    endif()

    cmate_run_prog(CMD ${CMAKE_COMMAND} ${ARGS})
endfunction()

function(cmate_configure_run_cmake TYPE)
    cmate_configure_cmake_common_args(ARGS)

    list(APPEND ARGS "-DCMAKE_BUILD_TYPE=${TYPE}")
    list(APPEND ARGS "-S" "${CMATE_ROOT_DIR}")
    list(APPEND ARGS "-B" "${CMATE_BUILD_DIR}/${TYPE}")

    if(CMATE_TOOLCHAIN)
        list(APPEND ARGS "--toolchain" "${CMATE_TOOLCHAIN}")
    endif()

    cmate_run_prog(CMD ${CMAKE_COMMAND} ${ARGS})
endfunction()

function(cmate_configure)
    file(MAKE_DIRECTORY "${CMATE_BUILD_DIR}/.cmate")
    set(CONFIGURED "${CMATE_BUILD_DIR}/.cmate/.configured")
    cmate_setg(CMATE_BUILD_TYPES "Debug;Release")

    if(EXISTS ${CONFIGURED})
        return()
    endif()

    cmate_check_ninja()

    if(CMATE_NINJA OR WIN32)
        cmate_configure_run_cmake_multi()
    else()
        foreach(TYPE ${CMATE_BUILD_TYPES})
            cmate_configure_run_cmake(${TYPE})
        endforeach()
    endif()

    file(TOUCH ${CONFIGURED})
endfunction()
