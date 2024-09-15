list(APPEND CMATE_CMDS "add")
set(CMATE_ADD_SHORT_HELP "Add a dependency to project.yaml")
set(
    CMATE_ADD_HELP
    "
Usage: cmate add URL

${CMATE_ADD_SHORT_HELP}"
)

function(cmate_add)
    cmate_conf_get("deps" DEPS)

    if(CMATE_ARGC EQUAL 0)
        cmate_die("missing URL")
    endif()

    list(GET CMATE_ARGS 0 URL)
    cmate_deps_parse(${URL} DEP)
    cmate_deps_get_dep(DEP)
endfunction()
