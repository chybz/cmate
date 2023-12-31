function(cmate_load_cmake_package_deps JSON PREFIX)
    cmate_json_get_array("${JSON}" "cmake" "PKGS")
    set(PACKAGES "")

    foreach(PKG ${PKGS})
        set(PKGTYPE "STRING")

        if("${PKG}" MATCHES "^[[{].*$")
            string(JSON PKGTYPE TYPE ${PKG})
        endif()

        if(${PKGTYPE} STREQUAL "STRING")
            # Simple module
            list(APPEND PACKAGES ${PKG})
        elseif(${PKGTYPE} STREQUAL "OBJECT")
            # Module and components
            string(JSON PKGNAME MEMBER ${PKG} 0)
            list(APPEND PACKAGES ${PKGNAME})

            cmate_json_get_array(${PKG} ${PKGNAME} "COMPS")

            set("${PREFIX}_CMAKE_${PKGNAME}_COMPS" ${COMPS} PARENT_SCOPE)
        endif()
    endforeach()

    set("${PREFIX}_CMAKE_PACKAGES" ${PACKAGES} PARENT_SCOPE)
endfunction()

function(cmate_load_pkgconfig_package_deps JSON PREFIX)
    cmate_json_get_array("${JSON}" "pkgconfig" "PKGS")
    set("${PREFIX}_PKGCONFIG_PACKAGES" ${PKGS} PARENT_SCOPE)
endfunction()

function(cmate_load_link_deps FILE PREFIX)
    set(PUBLIC_DEPS "")
    set(PRIVATE_DEPS "")
    set(LVAR "PUBLIC_DEPS")

    if(EXISTS ${FILE})
        file(READ ${FILE} JSON)
        string(JSON LIBS GET ${JSON} "libs")

        foreach(TYPE PUBLIC PRIVATE)
            # TODO: add more checks for correct JSON structure
            string(TOLOWER ${TYPE} KEY)
            cmate_json_get_array(${LIBS} ${KEY} "${TYPE}_DEPS")
        endforeach()
    endif()

    set(${PREFIX}_PUBLIC_DEPS ${PUBLIC_DEPS} PARENT_SCOPE)
    list(LENGTH PUBLIC_DEPS PUBLIC_DEPS_COUNT)
    set(${PREFIX}_PUBLIC_DEPS_COUNT ${PUBLIC_DEPS_COUNT} PARENT_SCOPE)

    set(${PREFIX}_PRIVATE_DEPS ${PRIVATE_DEPS} PARENT_SCOPE)
    list(LENGTH PRIVATE_DEPS PRIVATE_DEPS_COUNT)
    set(${PREFIX}_PRIVATE_DEPS_COUNT ${PRIVATE_DEPS_COUNT} PARENT_SCOPE)

    math(EXPR DEPS_COUNT "${PUBLIC_DEPS_COUNT} + ${PRIVATE_DEPS_COUNT}")
    set(${PREFIX}_DEPS_COUNT ${DEPS_COUNT} PARENT_SCOPE)
endfunction()
