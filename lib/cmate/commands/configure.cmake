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

function(cmate_configure_lib NAME TARGET SRC_BASE)
    if(${CMATE_DRY_RUN})
        cmate_msg("found library ${NAME}")
        return()
    endif()

    set(SDIR "${CMATE_ROOT_DIR}/${SRC_BASE}/${NAME}")
    set(CM_FILE "${SDIR}/CMakeLists.txt")
    set(LINK_FILE "${SDIR}/${CMATE_LINKFILE}")

    # Set target template variables
    set(T.NAME "${NAME}")
    set(T.TNAME "${TARGET}")
    string(TOUPPER ${TARGET} T.UTNAME)

    cmate_load_link_deps(${LINK_FILE} TARGET)
    cmate_tmpl_process(
        FROM "targets/lib/CMakeLists.txt.in"
        TO_VAR CONTENT
    )

    if(${CMATE_DUMP})
        message(${DEPS})
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

function(cmate_configure_cmake_package PKGDESC VAR)
    set(COMPS "")
    string(JSON T ERROR_VARIABLE ERR TYPE ${PKGDESC})

    if(T STREQUAL "OBJECT")
        string(JSON PKG MEMBER ${PKGDESC} 0)
        cmate_json_get_array(${PKGDESC} ${PKG} COMPS)
    else()
        set(PKG "${PKGDESC}")
    endif()

    set("${VAR}.PKG" ${PKG} PARENT_SCOPE)
    set("${VAR}.COMPS" ${COMPS} PARENT_SCOPE)

    list(LENGTH COMPS COMP_COUNT)
    set("${VAR}.COMP_COUNT" ${COMP_COUNT} PARENT_SCOPE)
endfunction()

function(cmate_configure_make_dep DEP VAR)
    string(JSON T ERROR_VARIABLE ERR TYPE ${DEP})

    if(T STREQUAL "OBJECT")
        string(JSON SPEC MEMBER ${DEP} 0)
        cmate_dep_parse(${SPEC} DEP)
        cmate_json_get_array(${DEP} ${SPEC} ARGS)
        set("DEP.ARGS" ${ARGS})
    else()
        cmate_dep_parse(${DEP} DEP)
    endif()

    set("${VAR}.HOST" ${DEP.HOST} PARENT_SCOPE)
    set("${VAR}.URL" ${DEP.URL} PARENT_SCOPE)
    set("${VAR}.REPO" ${DEP.REPO} PARENT_SCOPE)
    set("${VAR}.TAG" "${DEP.TAG}" PARENT_SCOPE)
    set("${VAR}.ARGS" "${DEP.ARGS}" PARENT_SCOPE)
endfunction()

function(cmate_configure_project_cmake_packages VAR)
    cmate_conf_get("packages.cmake" PKGS)

    list(LENGTH PKGS COUNT)
    set(PKGNAMES "")

    foreach(PKG ${PKGS})
        cmate_configure_cmake_package(${PKG} PC)
        list(APPEND PKGNAMES "${PC.PKG}")
        set("${VAR}.PKGS.${PC.PKG}.COMPS" "${PC.COMPS}" PARENT_SCOPE)
        set("${VAR}.PKGS.${PC.PKG}.COMP_COUNT" "${PC.COMP_COUNT}" PARENT_SCOPE)
    endforeach()

    set("${VAR}.PKGS" ${PKGNAMES} PARENT_SCOPE)

    list(LENGTH PKGNAMES PKG_COUNT)
    set("${VAR}.PKG_COUNT" ${PKG_COUNT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project_pkgconfig_packages VAR)
    cmate_conf_get("packages.pkgconfig" PKGS)

    list(LENGTH PKGNAMES COUNT)
    set("${VAR}.PKGS" ${PKGNAMES} PARENT_SCOPE)

    list(LENGTH PKGNAMES PKG_COUNT)
    set("${VAR}.PKG_COUNT" ${PKG_COUNT} PARENT_SCOPE)
endfunction()

function(cmate_configure_project)
    if(${CMATE_DRY_RUN})
        return()
    endif()

    set(CM_FILE "${CMATE_ROOT_DIR}/CMakeLists.txt")
    set(CMATE_CMAKE_VER 3.12)

    # Prepare dependencies sources
    cmate_conf_get("deps" DEPS)

    foreach(SPEC ${DEPS})
        cmate_configure_make_dep(${SPEC} DEP)
        list(APPEND "P.DEPS" ${DEP.REPO})
    endforeach()

    # Prepare CMake/PkgConfig dependencies names/structure
    foreach(PLIST "cmake;CM" "pkgconfig;PC")
        list(GET PLIST 0 PTYPE)
        list(GET PLIST 1 PVAR)
        cmake_language(
            CALL "cmate_configure_project_${PTYPE}_packages"
            "P.${PVAR}"
        )
    endforeach()

    set(P.TARGETS.BIN "")
    set(P.TARGETS.LIB "")

    # Target subdirs
    if(CMATE_BINS OR CMATE_LIBS)
        foreach(TYPE "LIB" "BIN")
            foreach(T ${CMATE_${TYPE}S})
                cmate_target_name(${T} ${TYPE} TNAME)
                list(APPEND P.TARGETS.${TYPE} ${TNAME})

                set(TDIR "src/${TYPE}/${T}")
                string(TOLOWER "${TDIR}" TDIR)

                set("P.TARGETS.${TYPE}.${TNAME}.SUBDIR" "${TDIR}")
                set("P.TARGETS.${TYPE}.${TNAME}.NAME" "${T}")
            endforeach()
        endforeach()
    else()
        cmate_die("no targets to configure")
    endif()

    list(APPEND P.TARGETS.INSTALL "${P.TARGETS.LIB}" "${P.TARGETS.BIN}")

    set(P.TARGETS.TEST "")

    if(CMATE_TESTS)
        set(TYPE "TEST")

        foreach(T ${CMATE_TESTS})
            cmate_target_name(${T} ${TYPE} TNAME)
            list(APPEND P.TARGETS.TEST ${TNAME})

            set(TDIR "src/${TYPE}/${T}")
            string(TOLOWER "${TDIR}" TDIR)

            set("P.TARGETS.${TYPE}.${TNAME}.SUBDIR" "${TDIR}")
        endforeach()
    endif()

    cmate_tmpl_process(FROM "project/CMakeLists.txt.in" TO_VAR CONTENT)

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
    # Set CMate global template variables
    set(CM.HPAT "${CMATE_HEADER_PAT}")
    set(CM.SPAT "${CMATE_SOURCE_PAT}")

    # Set project level template variables
    set(P.NAME "${CMATE_PROJECT.name}")
    string(TOUPPER "${CMATE_PROJECT.name}" P.UNAME)
    set(P.VER "${CMATE_PROJECT.version}")
    set(P.VER_MAJOR "${CMATE_PROJECT.version_major}")
    set(P.VER_MINOR "${CMATE_PROJECT.version_minor}")
    set(P.VER_PATCH "${CMATE_PROJECT.version_patch}")
    set(P.NS "${CMATE_PROJECT.namespace}")
    set(P.STD "${CMATE_PROJECT.std}")

    foreach(NAME ${CMATE_LIBS})
        cmate_target_name(${NAME} "lib" "TNAME")
        cmate_configure_lib(${NAME} ${TNAME} "src/lib")
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
