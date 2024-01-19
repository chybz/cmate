set(CMATE_HELP_HEADER "CMate v${CMATE_VER}")
list(APPEND CMATE_CMDS "help")

list(
    APPEND
    CMATE_OPTIONS
    "verbose"
    "cc"
)

function(cmate_build_help VAR)
    set(
        CMATE_HELP_PRE
    "
Usage: cmate [OPTIONS] COMMAND

Options:
  --verbose    Verbose operation
  --cc=ID      Compiler suite to use (overrides CMATE_CC)
               (e.g.: gcc, clang, gcc-10, clang-16, cl)
  --no-ninja   Don't use Ninja

Commands:
"
    )
    set(
        CMATE_HELP_POST
        "See 'cmate help <command>' to read about a specific subcommand."
    )
    set(LENGTH 0)
    string(APPEND HELP ${CMATE_HELP_PRE})

    foreach(CMD ${CMATE_CMDS})
        string(LENGTH "${CMD}" CL)

        if(CL GREATER ${LENGTH})
            set(LENGTH ${CL})
        endif()
    endforeach()

    foreach(CMD ${CMATE_CMDS})
        string(LENGTH "${CMD}" CL)
        math(EXPR PAD "${LENGTH}-${CL}")
        string(TOUPPER ${CMD} UCMD)
        set(CHVAR "CMATE_${UCMD}_SHORT_HELP")

        string(REPEAT " " ${PAD} CPAD)
        string(APPEND HELP "  ${CMD}${CPAD}    ${${CHVAR}}\n")
    endforeach()

    string(APPEND HELP "\n${CMATE_HELP_POST}")
    set(${VAR} ${HELP} PARENT_SCOPE)
endfunction()

function(cmate_help)
    set(HVAR "CMATE")
    if(CMATE_ARGC GREATER 0)
        # Sub command help
        list(GET CMATE_ARGS 0 HCMD)

        if(${HCMD} IN_LIST CMATE_CMDS)
            string(TOUPPER "${HCMD}" HCMD)
            string(APPEND HVAR "_${HCMD}_HELP")
            set(HELP ${${HVAR}})
        else()
            cmate_die("no such command: ${HCMD}")
        endif()
    else()
        # Global help
        cmate_build_help("HELP")
    endif()

    string(CONFIGURE ${HELP} HELP)

    message("${CMATE_HELP_HEADER}")
    message(${HELP})
endfunction()
