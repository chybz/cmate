function(cmate_dep_set_cache_dir NAME)
    string(REPLACE "/" "_" DIR ${NAME})
    set(DIR "${CMATE_DL_DIR}/${DIR}")
    cmate_setg(CMATE_DEP_CACHE_DIR ${DIR})
    cmate_setg(CMATE_DEP_SOURCE_DIR "${DIR}/sources")
    cmate_setg(CMATE_DEP_BUILD_DIR "${DIR}/build")
    cmate_setg(CMATE_DEP_STATE_DIR "${DIR}/state")
endfunction()

function(cmate_dep_state_file STATE VAR)
    set(${VAR} "${CMATE_DEP_STATE_DIR}/.${STATE}" PARENT_SCOPE)
endfunction()

function(cmate_dep_set_state STATE)
    file(MAKE_DIRECTORY ${CMATE_DEP_STATE_DIR})
    cmate_dep_state_file(${STATE} FILE)
    file(TOUCH ${FILE})
endfunction()

function(cmate_dep_get_repo HOST REPO REF)
    if(HOST MATCHES "^\\$\\{(.+)\\}$")
        # Dereference variable
        set(HOST ${${CMAKE_MATCH_1}})
    endif()

    if(HOST STREQUAL "GH")
        set(HOST "https://github.com")
    elseif(TYPE STREQUAL "GL")
        set(HOST "https://gitlab.com")
    endif()

    set(URL "${HOST}/${REPO}.git")

    set(GIT_ARGS "clone")
    list(
        APPEND GIT_ARGS
        -c advice.detachedHead=false
        --depth 1
    )

    if(REF)
        list(APPEND GIT_ARGS --branch "${REF}")
    endif()

    cmate_dep_set_cache_dir(${REPO})
    cmate_dep_state_file("fetched" FETCHED)

    if(NOT IS_DIRECTORY ${CMATE_DEP_SOURCE_DIR} OR NOT EXISTS ${FETCHED})
        # Whatever the reason, we're (re-)fetching
        file(REMOVE_RECURSE ${CMATE_DEP_SOURCE_DIR})
        cmate_info("cloning ${URL} in ${CMATE_DEP_SOURCE_DIR}")
        cmate_run_prog(CMD git ${GIT_ARGS} ${URL} ${CMATE_DEP_SOURCE_DIR})
        cmate_dep_set_state("fetched")
    endif()
endfunction()

function(cmate_dep_get_url URL)
    string(MD5 HASH ${URL})

    if(URL MATCHES "/([^/]+)$")
        set(FILE ${CMAKE_MATCH_1})
    else()
        cmate_die("can't find filename from URL: ${URL}")
    endif()

    cmate_dep_set_cache_dir(${HASH})
    cmate_dep_state_file("fetched" FETCHED)
    cmate_dep_state_file("extracted" EXTRACTED)
    set(CFILE "${CMATE_DEP_CACHE_DIR}/${FILE}")

    if(NOT EXISTS ${CFILE})
        cmate_info("downloading ${URL} in ${CDIR}")
        cmate_download(${URL} ${CFILE})
        cmate_dep_set_state("fetched")
    endif()

    if(NOT IS_DIRECTORY ${CMATE_DEP_SOURCE_DIR} OR NOT EXISTS ${EXTRACTED})
        file(REMOVE_RECURSE ${CMATE_DEP_SOURCE_DIR})
        cmate_info("extracting ${FILE}")
        file(
            ARCHIVE_EXTRACT
            INPUT ${CFILE}
            DESTINATION ${CMATE_DEP_SOURCE_DIR}
        )
        cmate_dep_set_state("extracted")
    endif()

    cmate_unique_dir(${CMATE_DEP_SOURCE_DIR} SDIR)
    cmate_setg(CMATE_DEP_SOURCE_DIR ${SDIR})
endfunction()

cmate_setg(CMATE_DEP_PROPS "TYPE;NAME;URL;HOST;REPO;TAG;ARGS;SRCDIR")

function(cmate_dep_parse SPEC VAR)
    if(SPEC MATCHES "^([A-Za-z0-9_]+)@([a-z]+://[^ ]+)$")
        # name@URL
        cmate_setprop(DEP TYPE "url")
        cmate_setprop(DEP NAME ${CMAKE_MATCH_1})
        cmate_setprop(DEP URL ${CMAKE_MATCH_2})
    elseif(SPEC MATCHES "^(([^: ]+):)?([^@ ]+)(@([^ ]+))?$")
        cmate_setprop(DEP TYPE "git")

        # GitHub/GitLab style project short ref
        if(CMAKE_MATCH_2)
            if(CMATE_${CMAKE_MATCH_2})
                cmate_setprop(DEP HOST ${CMATE_${CMAKE_MATCH_2}})
            else()
                cmate_die("unknown id: ${CMAKE_MATCH_2}")
            endif()
        else()
            cmate_setprop(DEP HOST ${CMATE_${CMATE_GIT_HOST}})
        endif()

        cmate_setprop(DEP REPO ${CMAKE_MATCH_3})
        cmate_setprop(DEP TAG "${CMAKE_MATCH_5}")
        cmate_setprop(DEP URL "${DEP.HOST}/${DEP.REPO}.git")
        set("DEP.NAME" ${DEP.REPO})
        string(REGEX REPLACE "[^A-Za-z0-9_]" "_" "DEP.NAME" "${DEP.NAME}")
    else()
        cmate_die("unable to parse dependency: ${SPEC}")
    endif()

    cmate_setprops(${VAR} DEP "${CMATE_DEP_PROPS}" PARENT_SCOPE)
endfunction()
