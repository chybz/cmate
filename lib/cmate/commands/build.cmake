list(APPEND CMATE_CMDS "build")
set(CMATE_BUILD_SHORT_HELP "Build local project")
set(
    CMATE_BUILD_HELP
    "
Usage: cmate build [OPTIONS]

${CMATE_BUILD_SHORT_HELP}

Options:
  --debug         Build in debug mode (default)
  --release       Build in release mode"
)

function(cmate_build)
    cmate_configure()
    cmate_unsetg(CMATE_BUILD_TYPES)

    cmate_set_build_types(
        CMATE_BUILD_DEBUG
        CMATE_BUILD_RELEASE
        "Debug"
    )

    foreach(TYPE ${CMATE_BUILD_TYPES})
        set(ARGS "")

        if (IS_DIRECTORY "${CMATE_BUILD_DIR}/${TYPE}")
            list(APPEND ARGS "--build" "${CMATE_BUILD_DIR}/${TYPE}")
        else()
            list(APPEND ARGS "--build" "${CMATE_BUILD_DIR}")
            list(APPEND ARGS "--config" "${TYPE}")
        endif()

        list(APPEND ARGS "--parallel")

        cmate_run_prog(CMD ${CMAKE_COMMAND} ${ARGS})
    endforeach()
endfunction()
