list(APPEND CMATE_CMDS "stage")
set(CMATE_STAGE_SHORT_HELP "Stage local project")
set(
    CMATE_STAGE_HELP
    "
Usage: cmate stage

${CMATE_STAGE_SHORT_HELP}"
)

function(cmate_stage)
    set(BUILD_DIR "${CMATE_ROOT_DIR}/build")
    set(ARGS "")

    list(APPEND ARGS "--install" "${BUILD_DIR}")

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
