list(APPEND CMATE_CMDS "build")
set(CMATE_BUILD_SHORT_HELP "Build local project")
set(
    CMATE_BUILD_HELP
    "
Usage: cmate build [OPTIONS]

${CMATE_BUILD_SHORT_HELP}

Options:
  --release       Build in release mode"
)

function(cmate_build)
    cmate_set_build_type(CMATE_BUILD_RELEASE)
    cmate_configure()

    set(ARGS "")
    list(APPEND ARGS "--build" "${CMATE_BUILD_DIR}")
    list(APPEND ARGS "--parallel")

    cmate_run_prog(CMD ${CMAKE_COMMAND} ${ARGS})
endfunction()
