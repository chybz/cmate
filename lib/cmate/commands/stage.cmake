list(APPEND CMATE_CMDS "stage")
set(CMATE_STAGE_SHORT_HELP "Stage local project")
set(
    CMATE_STAGE_HELP
    "
Usage: cmate stage

${CMATE_STAGE_SHORT_HELP}

Options:
  --debug         Stage debug build
  --release       Stage release build"
)

function(cmate_stage)
    cmate_set_build_types(
        CMATE_STAGE_DEBUG
        CMATE_STAGE_RELEASE
        "Debug"
    )

    cmate_build()

    foreach(TYPE ${CMATE_BUILD_TYPES})
        set(ARGS "")

        if (IS_DIRECTORY "${CMATE_BUILD_DIR}/${TYPE}")
            list(APPEND ARGS "--install" "${CMATE_BUILD_DIR}/${TYPE}")
        else()
            list(APPEND ARGS "--install" "${CMATE_BUILD_DIR}")
            list(APPEND ARGS "--config" "${TYPE}")
        endif()

        cmate_run_prog(CMD ${CMAKE_COMMAND} ${ARGS})
    endforeach()
endfunction()
