list(APPEND CMATE_CMDS "install")
set(CMATE_INSTALL_SHORT_HELP "Install dependencies listed in project.yaml")
set(
    CMATE_INSTALL_HELP
    "
Usage: cmate install

${CMATE_INSTALL_SHORT_HELP}"
)

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
            cmate_deps_parse(${SPEC} DEP)
            cmate_json_get_array(${DEP} "${SPEC};args" DEP.ARGS)
            cmate_json_get_array(${DEP} "${SPEC};srcdir" DEP.SRCDIR)
        elseif(T STREQUAL "STRING")
            cmate_deps_parse(${DEP} DEP)
        else()
            cmate_die("invalid dependency: expected object or string, got ${DEP}")
        endif()

        if(NOT "${DEP.REPO}" STREQUAL "")
            cmate_msg("checking ${DEP.REPO}")
            cmate_deps_get_repo(${DEP.HOST} ${DEP.REPO} "${DEP.TAG}")
        elseif(NOT "${DEP.URL}" STREQUAL "")
            cmate_msg("checking ${DEP.URL}")
            cmate_deps_get_url(${DEP.URL})
        else()
            cmate_die("invalid dependency: ${DEP}")
        endif()

        cmate_deps_install_dep("DEP")
    endforeach()
endfunction()
