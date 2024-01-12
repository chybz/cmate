list(APPEND CMATE_CMDS "stage")
set(CMATE_STAGE_SHORT_HELP "Stage local project")
set(
    CMATE_STAGE_HELP
    "
Usage: cmate stage

${CMATE_STAGE_SHORT_HELP}

Options:
  --release       Stage release build"
)

function(cmate_stage)
    cmate_set_build_type(CMATE_STAGE_RELEASE)
    cmate_build()

    set(ARGS "")

    list(APPEND ARGS "--install" "${CMATE_BUILD_DIR}")

    cmate_run_prog(CMD ${CMAKE_COMMAND} ${ARGS})
endfunction()
