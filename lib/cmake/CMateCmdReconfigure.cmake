list(APPEND CMATE_CMDS "reconfigure")
set(CMATE_RECONFIGURE_SHORT_HELP "Clean + configure")
set(
    CMATE_RECONFIGURE_HELP
    "
Usage: cmate reconfigure

${CMATE_RECONFIGURE_SHORT_HELP}"
)

function(cmate_reconfigure)
    cmate_clean()
    cmate_configure()
endfunction()
