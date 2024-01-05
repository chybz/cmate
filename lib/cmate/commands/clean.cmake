list(APPEND CMATE_CMDS "clean")
set(CMATE_CLEAN_SHORT_HELP "Clean local project")
set(
    CMATE_CLEAN_HELP
    "
Usage: cmate clean

${CMATE_CLEAN_SHORT_HELP}

Options:
  --purge       Remove everything: cenv, dependencies, ..."
)

function(cmate_clean)
    set(DIRS "BUILD" "STAGE" "STATE")

    if(${CMATE_CLEAN_PURGE})
        list(APPEND DIRS "ENV" "DEPS")
    endif()

    foreach(DIR ${DIRS})
        set(DVAR "CMATE_${DIR}_DIR")

        if (IS_DIRECTORY ${${DVAR}})
            cmate_msg("cleaning: ${${DVAR}}")
            file(REMOVE_RECURSE ${${DVAR}})
        endif()
    endforeach()
endfunction()
