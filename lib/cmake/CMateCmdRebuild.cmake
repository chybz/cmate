list(APPEND CMATE_CMDS "rebuild")
set(CMATE_REBUILD_SHORT_HELP "Reconfigure + build")
set(
    CMATE_REBUILD_HELP
    "
Usage: cmate rebuild

${CMATE_REBUILD_SHORT_HELP}"
)

function(cmate_rebuild)
    cmate_reconfigure()
    cmate_build()
endfunction()
