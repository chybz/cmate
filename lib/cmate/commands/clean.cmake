list(APPEND CMATE_CMDS "clean")
set(CMATE_CLEAN_SHORT_HELP "Clean local project")
set(
    CMATE_CLEAN_HELP
    "
Usage: cmate clean

${CMATE_CLEAN_SHORT_HELP}"
)

function(cmate_clean)
    set(BUILD_DIR "${CMATE_ROOT_DIR}/build")
    cmate_msg("cleaning: ${BUILD_DIR}")

    if (IS_DIRECTORY ${BUILD_DIR})
        file(REMOVE_RECURSE ${BUILD_DIR})
    endif()

    cmate_clear_states()
endfunction()
