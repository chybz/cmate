list(APPEND CMATE_CMDS "config")
set(CMATE_CONFIG_SHORT_HELP "Local project configuration")
set(
    CMATE_CONFIG_HELP
    "
Usage: cmate config [COMMAND]

${CMATE_CONFIG_SHORT_HELP}

Commands:
  show       Dumps config as JSON"
)

function(cmate_config_show)
    cmate_msg(${CMATE_CONF})
endfunction()

function(cmate_config)
    if(CMATE_ARGC LESS 1)
        cmate_die("missing config command")
    endif()

    list(GET CMATE_ARGS 0 CMD)

    set(CMATE_CONFIG_COMMAND "cmate_config_${CMD}")

    if(COMMAND "${CMATE_CONFIG_COMMAND}")
        cmake_language(CALL ${CMATE_CONFIG_COMMAND})
    else()
        cmate_msg("unknown command: ${CMATE_CONFIG_COMMAND}")
    endif()
endfunction()
