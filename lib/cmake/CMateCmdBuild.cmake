list(APPEND CMATE_CMDS "build")
set(CMATE_BUILD_SHORT_HELP "Build local project")
set(
    CMATE_BUILD_HELP
    "
Usage: cmate build

${CMATE_BUILD_SHORT_HELP}"
)

function(cmate_build)
    cmate_state_file("configured" CONFIGURED)

    if(NOT EXISTS ${CONFIGURED})
        cmate_die("please configure first")
    endif()

    set(BUILD_DIR "${CMATE_ROOT_DIR}/build")
    set(STAGE_DIR "${CMATE_ROOT_DIR}/stage")
    set(ARGS "")

    list(APPEND ARGS "--build" "${BUILD_DIR}")
    list(APPEND ARGS "--parallel")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND}
            ${ARGS}
        RESULTS_VARIABLE RC
    )

    if(RC)
        list(JOIN ARGS " " RUN_CMD)
        cmate_die("command failed: ${RUN_CMD}")
    endif()
endfunction()
