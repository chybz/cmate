set(CMATE_NEW_ALLOW_NO_CONF 1)
set(CMATE_NEW_DEFAULT_VERSION "0.1.0")
set(CMATE_NEW_DEFAULT_STD "20")

list(APPEND CMATE_CMDS "new")
list(
    APPEND
    CMATE_NEW_OPTIONS
    "name"
    "version"
    "namespace"
    "std"
)
set(CMATE_NEW_SHORT_HELP "Create new local project")
set(
    CMATE_NEW_HELP
    "
Usage: cmate new [OPTIONS]

${CMATE_NEW_SHORT_HELP}

Options:
  --name=NAME            Project name
  --version=SEMVER       Project version (default: ${CMATE_NEW_DEFAULT_VERSION})
  --namespace=NAMESPACE  Project C++ namespace (default: project name)
  --std=STD              Project C++ standard (default: ${CMATE_NEW_DEFAULT_STD})"
)

function(cmate_new_set_conf)
    set(OPTS "")
    set(SINGLE VAR KEY DEFAULT)
    set(MULTI "")
    cmake_parse_arguments(NEW "${OPTS}" "${SINGLE}" "${MULTI}" ${ARGN})

    if(${NEW_VAR})
        set(VAL "${${NEW_VAR}}")
    else()
        set(VAL "${NEW_DEFAULT}")
    endif()

    cmate_conf_set_str("${NEW_KEY}" "${VAL}")
endfunction()

function(cmate_new)
    if(NOT CMATE_NEW_NAME)
        cmate_die("missing project name")
    else()
        cmate_conf_set_str("name" "${CMATE_NEW_NAME}")
    endif()

    cmate_new_set_conf(KEY "version" VAR CMATE_NEW_VERSION DEFAULT "${CMATE_NEW_DEFAULT_VERSION}")
    cmate_new_set_conf(KEY "namespace" VAR CMATE_NEW_NAMESPACE DEFAULT "${CMATE_NEW_NAME}")
    cmate_new_set_conf(KEY "std" VAR CMATE_NEW_STD DEFAULT "${CMATE_NEW_DEFAULT_STD}")

    cmate_save_conf("${CMATE_PRJFILE}")
endfunction()
