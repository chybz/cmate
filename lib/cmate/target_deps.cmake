function(cmate_load_link_deps FILE PREFIX)
    set(TOTAL 0)

    cmate_yaml_load(${FILE} LINK)

    foreach(TYPE "public" "private")
        cmate_conf_get("libs.${TYPE}" DEPS ${LINK})

        string(TOUPPER ${TYPE} UTYPE)
        set(${PREFIX}_${UTYPE}_DEPS ${DEPS} PARENT_SCOPE)
        list(LENGTH DEPS DEPS_COUNT)
        set(${PREFIX}_${UTYPE}_DEPS_COUNT ${DEPS_COUNT} PARENT_SCOPE)

        math(EXPR TOTAL "${TOTAL} + ${DEPS_COUNT}")
    endforeach()

    set(${PREFIX}_DEPS_COUNT ${TOTAL} PARENT_SCOPE)
endfunction()

function(cmate_target_link_deps NAME FILE VAR)
    cmate_load_link_deps(${FILE} TGT)

    if(${TGT_DEPS_COUNT} GREATER 0)
        set(TDEPS "\ntarget_link_libraries(\n    ${NAME}")

        foreach(TYPE PUBLIC PRIVATE)
            if(${TGT_${TYPE}_DEPS_COUNT} GREATER 0)
                string(APPEND TDEPS "\n    ${TYPE}")

                foreach(DEP ${TGT_${TYPE}_DEPS})
                    string(APPEND TDEPS "\n        ${DEP}")
                endforeach()
            endif()
        endforeach()

        string(APPEND TDEPS "\n)\n")
        set(${VAR} ${TDEPS} PARENT_SCOPE)
    endif()
endfunction()

function(cmate_target_name NAME TYPE VAR)
    string(TOLOWER "${CMATE_PROJECT.namespace}_${NAME}_${TYPE}" TBASE)
    string(REPLACE "-" "_" TBASE ${TBASE})
    set(${VAR} ${TBASE} PARENT_SCOPE)
endfunction()
