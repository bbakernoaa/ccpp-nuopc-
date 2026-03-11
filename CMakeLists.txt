cmake_minimum_required(VERSION 3.15)
project(ccpp-nuopc LANGUAGES Fortran)

# Add cmake directory to module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Find ESMF
find_package(ESMF REQUIRED)

# Discovery PIO and NetCDF from ESMF if possible
function(find_root_by_file root_var filename)
    if(NOT ${root_var})
        # Try searching in include directories first
        foreach(inc ${ESMF_INCLUDE_DIRS})
            if(EXISTS "${inc}/${filename}")
                get_filename_component(root "${inc}" DIRECTORY)
                set(${root_var} "${root}" PARENT_SCOPE)
                message(STATUS "Found ${root_var} from ESMF include path: ${root}")
                return()
            endif()
        endforeach()
        # Then try link paths
        foreach(lib ${ESMF_LIBRARIES})
            if(lib MATCHES "^-L(.*)")
                set(search_path "${CMAKE_MATCH_1}")
                if(EXISTS "${search_path}/../include/${filename}")
                    set(root "${search_path}/..")
                    get_filename_component(root "${root}" ABSOLUTE)
                    set(${root_var} "${root}" PARENT_SCOPE)
                    message(STATUS "Found ${root_var} from ESMF link path: ${root}")
                    return()
                endif()
            endif()
        endforeach()
    endif()
endfunction()

find_root_by_file(PIO_ROOT "pio.h")

if(PIO_ROOT)
    message(STATUS "Using PIO_ROOT: ${PIO_ROOT}")
    set(PIO_C_LIBRARIES "${PIO_ROOT}/lib/libpioc.so" CACHE STRING "PIO C libs" FORCE)
    set(PIO_C_INCLUDE_DIRS "${PIO_ROOT}/include" CACHE STRING "PIO C includes" FORCE)
    set(PIO_Fortran_LIBRARIES "${PIO_ROOT}/lib/libpiof.so;${PIO_ROOT}/lib/libpioc.so" CACHE STRING "PIO Fortran libs" FORCE)
    set(PIO_Fortran_INCLUDE_DIRS "${PIO_ROOT}/include" CACHE STRING "PIO Fortran includes" FORCE)
    set(PIO_FOUND TRUE CACHE BOOL "PIO found" FORCE)
    set(PIO_C_FOUND TRUE CACHE BOOL "PIO C found" FORCE)
    set(PIO_Fortran_FOUND TRUE CACHE BOOL "PIO Fortran found" FORCE)
endif()

# Check if CDEPS is already available (e.g. via Spack)
find_package(CDEPS QUIET)

if(NOT CDEPS_FOUND)
    message(STATUS "CDEPS not found on system, attempting to build from source...")
    set(cdeps_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/cdeps-src")
    set(cdeps_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/cdeps-build")
    if(NOT EXISTS "${cdeps_SOURCE_DIR}/CMakeLists.txt")
        message(STATUS "Downloading CDEPS develop...")
        execute_process(COMMAND git clone --recursive -b develop https://github.com/noaa-emc/cdeps.git ${cdeps_SOURCE_DIR})
    endif()

    # Force CDEPS flags
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -ffree-line-length-none -DCPRGNU" CACHE STRING "Fortran flags" FORCE)
    set(DISABLE_FoX ON CACHE BOOL "Disable FoX library" FORCE)
    set(COMPILER "gnu" CACHE STRING "Compiler type")

    set(ESMF_F90COMPILEPATHS "${ESMF_INCLUDE_DIRS}" CACHE STRING "ESMF include paths" FORCE)

    # RUN THE PATCH SCRIPT
    execute_process(COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/patch_dependencies.py ${cdeps_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-physics")

    add_subdirectory(${cdeps_SOURCE_DIR} ${cdeps_BINARY_DIR})

    if(TARGET dshr)
        set(CDEPS_FOUND TRUE)
        # Ensure CDEPS can find ESMF modules
        target_include_directories(cdeps_share PUBLIC ${ESMF_INCLUDE_DIRS})
        target_include_directories(streams PUBLIC ${ESMF_INCLUDE_DIRS})
        target_include_directories(dshr PUBLIC ${ESMF_INCLUDE_DIRS})
    endif()
endif()

# Add internal state library
add_library(ccpp_internal_state src/ccpp_internal_state.F90)
target_link_libraries(ccpp_internal_state PUBLIC ESMF::ESMF)
target_include_directories(ccpp_internal_state PUBLIC ${CMAKE_CURRENT_BINARY_DIR})

# Add NUOPC cap library
add_library(ccpp_nuopc_cap src/ccpp_nuopc_cap.F90 src/ccpp_inline_cdeps_mod.F90)
target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_internal_state ESMF::ESMF cdeps_share streams dshr)
target_include_directories(ccpp_nuopc_cap PUBLIC ${ESMF_INCLUDE_DIRS})
target_include_directories(ccpp_nuopc_cap PUBLIC ${cdeps_SOURCE_DIR}/share ${cdeps_SOURCE_DIR}/streams ${cdeps_SOURCE_DIR}/dshr)
# Add binary directories for generated modules
target_include_directories(ccpp_nuopc_cap PUBLIC ${cdeps_BINARY_DIR}/share ${cdeps_BINARY_DIR}/streams ${cdeps_BINARY_DIR}/dshr)

# Prepare for CCPP submodules
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-framework/CMakeLists.txt")
    add_subdirectory(src/ccpp-framework)
    target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_framework)
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-physics/CMakeLists.txt")
    set(ENV{CCPP_TYPEDEFS} "")
    set(ENV{CCPP_SCHEMES} "")
    set(ENV{CCPP_CAPS} "")
    add_subdirectory(src/ccpp-physics)
    target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_physics)
endif()
