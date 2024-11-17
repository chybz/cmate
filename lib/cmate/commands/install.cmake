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

    foreach(SPEC ${DEPS})
        cmate_deps_make_dep(${SPEC} DEP)
        cmate_deps_get_dep(DEP)
        cmate_deps_install_dep(DEP)
    endforeach()
endfunction()
