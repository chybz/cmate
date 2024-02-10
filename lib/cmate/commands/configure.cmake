list(APPEND CMATE_CMDS "configure")
list(
    APPEND
    CMATE_CONFIGURE_OPTIONS
    "no-tests"
    "toolchain"
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
  --no-tests             Don't build tests
  --toolchain=FILE       CMake toolchain file
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

    if(CMATE_PROJECT.namespace)
        string(
            APPEND
            CONTENT
            "add_library(${CMATE_PROJECT.namespace}::${NAME} ALIAS ${TBASE})\n"
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
        $<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}/${CMATE_PROJECT.namespace}>
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
        CXX_STANDARD ${CMATE_PROJECT.std}
        VERSION ${CMATE_PROJECT.version}
        SOVERSION ${CMATE_PROJECT.version_major}.${CMATE_PROJECT.version_minor}
        EXPORT_NAME ${NAME}
        OUTPUT_NAME ${CMATE_PROJECT.namespace}_${NAME}
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
        CXX_STANDARD ${CMATE_PROJECT.std}
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

function(cmate_configure_cmake_set_pkg PKGDESC PKGVAR COMPSVAR)
    set(PKG "")
    set(COMPS "")

    string(JSON T ERROR_VARIABLE ERR TYPE ${PKGDESC})

    if(T STREQUAL "OBJECT")
        string(JSON PKG MEMBER ${PKGDESC} 0)
        cmate_json_get_array(${PKGDESC} ${PKG} COMPS)
    else()
        set(PKG "${PKGDESC}")
    endif()

    set(${PKGVAR} ${PKG} PARENT_SCOPE)
    set(${COMPSVAR} ${COMPS} PARENT_SCOPE)
endfunction()

function(cmate_configure_cmake_package PKGDESC VAR)
    set(CONTENT "")
    cmate_configure_cmake_set_pkg(${PKGDESC} PKG COMPS)

    if(COMPS)
        list(JOIN COMPS "\n        " COMPS)
        set(TMPL "project/CMakeLists-pkg-cmake-comps.txt.in")
    else()
        set(TMPL "project/CMakeLists-pkg-cmake.txt.in")
    endif()

    cmate_tmpl_configure(${TMPL} CONTENT)

    set(${VAR} ${CONTENT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project_cmake_packages VAR)
    set(CONTENT "")
    cmate_conf_get("packages.cmake" PKGS)

    foreach(PKG ${PKGS})
        cmate_configure_cmake_package(${PKG} PC)
        string(APPEND CONTENT "${PC}")
    endforeach()

    set(${VAR} ${CONTENT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project_pkgconfig_packages VAR)
    set(CONTENT "")
    cmate_conf_get("packages.pkgconfig" PKGS)

    if(PKGS)
        string(APPEND CONTENT "\n")
    endif()

    foreach(PKG ${PKGS})
        cmate_tmpl_configure(
            "project/CMakeLists-pkg-pkgconfig.txt.in"
            CONTENT
            "\n"
        )
    endforeach()

    set(${VAR} ${CONTENT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project_packages VAR)
    set(CONTENT "")

    foreach(PTYPE "cmake" "pkgconfig")
        cmake_language(
            CALL "cmate_configure_project_${PTYPE}_packages"
            PKGS
        )
        string(APPEND CONTENT "${PKGS}")
    endforeach()

    set(${VAR} ${CONTENT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project)
    if(${CMATE_DRY_RUN})
        return()
    endif()

    set(CONTENT "")
    set(CM_FILE "${CMATE_ROOT_DIR}/CMakeLists.txt")

    set(CMATE_CMAKE_VER 3.12)
    set(P ${CMATE_PROJECT.name})
    string(TOUPPER "${P}" P)

    cmate_tmpl_configure("project/CMakeLists-header.txt.in" CONTENT)

    # Options
    cmate_tmpl_configure("project/CMakeLists-options.txt.in" CONTENT "\n")

    cmate_configure_project_packages(PKGS)
    string(APPEND CONTENT "\n${PKGS}")

    set(ITARGETS "")

    # Target subdirs
    if(CMATE_BINS OR CMATE_LIBS)
        string(APPEND CONTENT "\n")

        foreach(TYPE "LIB" "BIN")
            foreach(T ${CMATE_${TYPE}S})
                cmate_target_name(${T} ${TYPE} TNAME)
                list(APPEND ITARGETS ${TNAME})

                set(TDIR "src/${TYPE}/${T}")
                string(TOLOWER "${TDIR}" TDIR)
                string(APPEND CONTENT "add_subdirectory(${TDIR})\n")
            endforeach()
        endforeach()
    else()
        cmate_die("no targets to configure")
    endif()

    if(CMATE_TESTS)
        string(APPEND CONTENT "if(${BUILD_TESTS})\n")
        string(APPEND CONTENT "    include(CTest)\n")
        string(APPEND CONTENT "    enable_testing()\n")

        foreach(T ${CMATE_TESTS})
            set(TDIR "src/tests/${T}")
            string(TOLOWER "${TDIR}" TDIR)
            string(APPEND CONTENT "    add_subdirectory(${TDIR})\n")
        endforeach()

        string(APPEND CONTENT "endif()\n")
    endif()

    string(
        APPEND
        CONTENT
        "
install(
    TARGETS"
    )

    foreach(TARGET ${ITARGETS})
        string(APPEND CONTENT "\n        ${TARGET}")
    endforeach()

    string(
        APPEND
        CONTENT
        "
    EXPORT ${CMATE_PROJECT.name}-config
    RUNTIME DESTINATION \${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION \${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION \${CMAKE_INSTALL_LIBDIR}
)

install(
    EXPORT ${CMATE_PROJECT.name}-config
    FILE ${CMATE_PROJECT.name}-config.cmake
    NAMESPACE ${CMATE_PROJECT.namespace}::
    DESTINATION \${CMAKE_INSTALL_LIBDIR}/cmake/${CMATE_PROJECT.name}
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
    DESTINATION \${CMAKE_INSTALL_INCLUDEDIR}/${CMATE_PROJECT.namespace}
)
"
            )
        endforeach()
    endif()

    file(WRITE ${CM_FILE} ${CONTENT})
endfunction()

function(cmate_configure_load_targets PREFIX)
    set(JSON "{}")
    set(TARGETS "")

    if(EXISTS ${CMATE_TARGETS_FILE})
        file(READ ${CMATE_TARGETS_FILE} JSON)
    endif()

    foreach(TYPE "LIB" "BIN" "TEST")
        string(TOLOWER "${TYPE}S" KEY)
        cmate_json_get_array(${JSON} ${KEY} LST)

        foreach(T ${LST})
            cmate_target_name(${T} ${TYPE} "TNAME")
            list(APPEND TARGETS "${TNAME}")
        endforeach()

        set("${PREFIX}_${TYPE}S" "${LST}" PARENT_SCOPE)
    endforeach()

    set("${PREFIX}_TARGETS" "${TARGETS}" PARENT_SCOPE)
endfunction()

function(cmate_configure_save_targets)
    set(JSON "{}")

    foreach(LST "LIBS" "BINS" "TESTS")
        string(TOLOWER "${LST}" KEY)
        cmate_json_set_array(JSON ${JSON} ${KEY} "${CMATE_${LST}}")
    endforeach()

    file(WRITE "${CMATE_TARGETS_FILE}" ${JSON})
endfunction()

function(cmate_configure_find_targets)
    file(GLOB LIB_INC_DIRS "${CMATE_ROOT_DIR}/include/*")
    set(TARGETS "")
    set(LIBS "")
    set(BINS "")
    set(TESTS "")

    # Libraries
    foreach(LIB_INC_DIR ${LIB_INC_DIRS})
        string(REPLACE "${CMATE_ROOT_DIR}/include/" "" NAME ${LIB_INC_DIR})
        cmate_target_name(${NAME} "lib" "TNAME")
        list(APPEND TARGETS ${TNAME})
        list(APPEND LIBS ${NAME})
    endforeach()

    # Binaries and tests
    foreach(TYPE bin test)
        file(GLOB SRC_DIRS "${CMATE_ROOT_DIR}/src/${TYPE}/*")
        set(TVAR "${TYPE}s")
        string(TOUPPER ${TVAR} TVAR)

        foreach(SRC_DIR ${SRC_DIRS})
            string(REPLACE "${CMATE_ROOT_DIR}/src/${TYPE}/" "" NAME ${SRC_DIR})
            cmate_target_name(${NAME} ${TYPE} "TNAME")
            list(APPEND TARGETS ${TNAME})
            list(APPEND ${TVAR} ${NAME})
        endforeach()
    endforeach()

    foreach(LST "TARGETS" "LIBS" "BINS" "TESTS")
        list(SORT ${LST})
        set(LVAR "CMATE_${LST}")
        cmate_setg(${LVAR} "${${LST}}")
    endforeach()
endfunction()

function(cmate_configure_clean)
    foreach(TYPE "BIN" "LIB" "TEST")
        if(NOT CMATE_${TYPE}S)
            continue()
        endif()

        foreach(T ${CMATE_${TYPE}S})
            set(TDIR "${CMATE_ROOT_DIR}/src/${TYPE}/${T}")
            string(TOLOWER "${TDIR}" TDIR)
            file(REMOVE "${TDIR}/CMakeLists.txt")
        endforeach()
    endforeach()

    file(REMOVE "${CMATE_ROOT_DIR}/CMakeLists.txt")
endfunction()

function(cmate_configure_needed VAR LIBS BINS TESTS)
    set(RES FALSE)

    foreach(LST "LIBS" "BINS" "TESTS")
        set(REFL ${CMATE_${LST}})
        list(SORT REFL)
        list(JOIN REFL "_" REFS)
        set(L ${${LST}})
        list(SORT L)
        list(JOIN L "_" S)

        if(NOT "${S}" STREQUAL "${REFS}")
            set(RES TRUE)
            break()
        endif()
    endforeach()

    set(${VAR} ${RES} PARENT_SCOPE)
endfunction()

function(cmate_configure_generate)
    foreach(NAME ${CMATE_LIBS})
        cmate_target_name(${NAME} "lib" "TNAME")
        cmate_configure_lib(${NAME} ${TNAME} "include" "src/lib")
    endforeach()

    # Binaries and tests
    foreach(TYPE "bin" "test")
        string(TOUPPER "CMATE_${TYPE}S" LNAME)

        if(NOT ${LNAME})
            continue()
        endif()

        foreach(NAME ${${LNAME}})
            cmate_target_name(${NAME} ${TYPE} "TNAME")
            cmake_language(
                CALL "cmate_configure_${TYPE}"
                ${NAME} ${TNAME} "src/${TYPE}"
            )
        endforeach()
    endforeach()

    # Top-level project
    cmate_configure_project()
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

    cmate_project_varname("BUILD_TESTS" BUILD_TESTS)

    if(CMATE_CONFIGURE_NO_TESTS)
        list(APPEND ARGS "-D${BUILD_TESTS}=OFF")
        list(APPEND ARGS "-DBUILD_TESTING=OFF")
    else()
        list(APPEND ARGS "-D${BUILD_TESTS}=ON")
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
    cmate_configure_find_targets()
    cmate_configure_load_targets(PREV)
    cmate_configure_needed(
        NEEDED
        "${PREV_LIBS}" "${PREV_BINS}" "${PREV_TESTS}"
    )

    if(NOT NEEDED)
        return()
    endif()

    cmate_configure_generate()

    cmate_setg(CMATE_BUILD_TYPES "Debug;Release")

    cmate_check_ninja()

    if(CMATE_NINJA OR WIN32)
        cmate_configure_run_cmake_multi()
    else()
        foreach(TYPE ${CMATE_BUILD_TYPES})
            cmate_configure_run_cmake(${TYPE})
        endforeach()
    endif()

    cmate_configure_save_targets()
endfunction()
