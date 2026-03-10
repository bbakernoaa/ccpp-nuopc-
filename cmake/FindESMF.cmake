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

        # Helper macro to parse esmf.mk
        macro(parse_esmf_mk VARNAME)
            file(STRINGS ${ESMFMKFILE} _line REGEX "^${VARNAME} = ")
            if(_line)
                string(REPLACE "${VARNAME} = " "" _val "${_line}")
                string(STRIP "${_val}" ${VARNAME})
            endif()
        endmacro()

        parse_esmf_mk(ESMF_F90COMPILEPATHS)
        parse_esmf_mk(ESMF_F90LINKPATHS)
        parse_esmf_mk(ESMF_F90LINKRPATHS)
        parse_esmf_mk(ESMF_F90ESMFLINKLIBS)

        # Convert compile paths (-I/path) to include directories (/path)
        string(REPLACE "-I" "" _inc_dirs "${ESMF_F90COMPILEPATHS}")
        separate_arguments(_inc_dirs)

        # Convert link paths (-L/path) to link directories (/path)
        string(REPLACE "-L" "" _link_dirs "${ESMF_F90LINKPATHS}")
        separate_arguments(_link_dirs)

        # Extract library names (-lesmf)
        string(REPLACE "-l" "" _libs "${ESMF_F90ESMFLINKLIBS}")
        separate_arguments(_libs)

        add_library(ESMF::ESMF INTERFACE IMPORTED)
        set_target_properties(ESMF::ESMF PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${_inc_dirs}"
            INTERFACE_LINK_DIRECTORIES "${_link_dirs}"
            INTERFACE_LINK_LIBRARIES "${_libs}"
        )

        set(ESMF_FOUND TRUE)
    else()
        message(WARNING "ESMFMKFILE not found. Set the ESMFMKFILE environment variable.")
        set(ESMF_FOUND FALSE)
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ESMF DEFAULT_MSG ESMF_FOUND)
