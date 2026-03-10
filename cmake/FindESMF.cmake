# FindESMF.cmake
# This module finds the Earth System Modeling Framework (ESMF)
# and defines the ESMF::ESMF imported target.
# It uses the ESMFMKFILE environment variable or a provided path.

if(NOT TARGET ESMF::ESMF)
    if(NOT DEFINED ESMFMKFILE)
        if(DEFINED ENV{ESMFMKFILE})
            set(ESMFMKFILE $ENV{ESMFMKFILE})
        else()
            # Try to find esmf.mk in CMAKE_PREFIX_PATH or standard locations
            find_file(ESMFMKFILE esmf.mk PATH_SUFFIXES lib lib/static)
        endif()
    endif()

    if(ESMFMKFILE AND EXISTS ${ESMFMKFILE})
        message(STATUS "Found ESMFMKFILE: ${ESMFMKFILE}")

        # Helper macro to parse esmf.mk more robustly
        macro(parse_esmf_mk VARNAME)
            file(STRINGS "${ESMFMKFILE}" _line REGEX "^[ \t]*${VARNAME}[ \t]*=")
            if(_line)
                # Take the last match if there are multiple
                list(GET _line -1 _line_val)
                # Remove the variable name and equals sign
                string(REGEX REPLACE "^[ \t]*${VARNAME}[ \t]*=[ \t]*" "" _val "${_line_val}")
                string(STRIP "${_val}" ${VARNAME})
                message(STATUS "Parsed from ${ESMFMKFILE}: ${VARNAME} = ${${VARNAME}}")
            endif()
        endmacro()

        parse_esmf_mk(ESMF_F90COMPILEPATHS)
        parse_esmf_mk(ESMF_F90LINKPATHS)
        parse_esmf_mk(ESMF_F90ESMFLINKLIBS)

        # Convert compile paths (-I/path) to include directories (/path)
        set(_inc_dirs "")
        if(ESMF_F90COMPILEPATHS)
            # Replace "-I" with ";" to create a list, but handle it carefully
            string(REPLACE "-I" ";" _raw_inc_list "${ESMF_F90COMPILEPATHS}")
            foreach(_dir IN LISTS _raw_inc_list)
                string(STRIP "${_dir}" _dir)
                if(_dir)
                    list(APPEND _inc_dirs "${_dir}")
                endif()
            endforeach()
        endif()

        # Convert link paths (-L/path) to link directories (/path)
        set(_link_dirs "")
        if(ESMF_F90LINKPATHS)
            string(REPLACE "-L" ";" _raw_link_list "${ESMF_F90LINKPATHS}")
            foreach(_dir IN LISTS _raw_link_list)
                string(STRIP "${_dir}" _dir)
                if(_dir)
                    list(APPEND _link_dirs "${_dir}")
                endif()
            endforeach()
        endif()

        # Extract library names (-lesmf)
        set(_libs "")
        if(ESMF_F90ESMFLINKLIBS)
            # Some entries might be full paths or -l names
            string(REGEX REPLACE "[ \t]+" ";" _raw_lib_list "${ESMF_F90ESMFLINKLIBS}")
            foreach(_lib IN LISTS _raw_lib_list)
                string(STRIP "${_lib}" _lib)
                if(_lib)
                    if(_lib MATCHES "^-l")
                        string(REGEX REPLACE "^-l" "" _lib_name "${_lib}")
                        list(APPEND _libs "${_lib_name}")
                    else()
                        list(APPEND _libs "${_lib}")
                    endif()
                endif()
            endforeach()
        endif()

        add_library(ESMF::ESMF INTERFACE IMPORTED)
        set_target_properties(ESMF::ESMF PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${_inc_dirs}"
            INTERFACE_LINK_DIRECTORIES "${_link_dirs}"
            INTERFACE_LINK_LIBRARIES "${_libs}"
        )

        message(STATUS "ESMF processed include directories: ${_inc_dirs}")

        set(ESMF_FOUND TRUE)
    else()
        message(WARNING "ESMFMKFILE not found. Set the ESMFMKFILE environment variable.")
        set(ESMF_FOUND FALSE)
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ESMF DEFAULT_MSG ESMF_FOUND)
