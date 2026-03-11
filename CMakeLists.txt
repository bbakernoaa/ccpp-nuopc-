cmake_minimum_required(VERSION 3.15)
project(ccpp-nuopc LANGUAGES Fortran)

# Add cmake directory to module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Find ESMF
find_package(ESMF REQUIRED)

# Find OpenMP
find_package(OpenMP REQUIRED)

# Define a main module directory for subprojects to share
set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/fortran_modules)
file(MAKE_DIRECTORY ${CMAKE_Fortran_MODULE_DIRECTORY})

# Check if CDEPS is already available (e.g. via Spack)
find_package(CDEPS QUIET)

if(NOT CDEPS_FOUND)
    message(STATUS "CDEPS not found on system, attempting to build from source...")

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

    # Manual checkout of CDEPS develop branch
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

    # ESMF modules for CDEPS
    set(ESMF_F90COMPILEPATHS "${ESMF_INCLUDE_DIRS}" CACHE STRING "ESMF include paths" FORCE)

    # RUN THE PATCH SCRIPT
    execute_process(COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/patch_dependencies.py ${cdeps_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-physics")

    # Add CDEPS subdirectory
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
target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_internal_state ESMF::ESMF cdeps_share streams dshr OpenMP::OpenMP_Fortran)
target_include_directories(ccpp_nuopc_cap PUBLIC ${ESMF_INCLUDE_DIRS})
target_include_directories(ccpp_nuopc_cap PUBLIC ${cdeps_SOURCE_DIR}/share ${cdeps_SOURCE_DIR}/streams ${cdeps_SOURCE_DIR}/dshr)

# Prepare for CCPP submodules
set(ccpp_framework_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-framework")
set(ccpp_physics_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-physics")

if(NOT EXISTS "${ccpp_framework_DIR}/CMakeLists.txt")
    message(STATUS "Downloading CCPP Framework...")
    execute_process(COMMAND rm -rf ${ccpp_framework_DIR} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    execute_process(COMMAND git clone --recursive https://github.com/bbakernoaa/ccpp-framework.git ${ccpp_framework_DIR}
                    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endif()

if(NOT EXISTS "${ccpp_physics_DIR}/CMakeLists.txt")
    message(STATUS "Downloading CCPP Physics...")
    execute_process(COMMAND rm -rf ${ccpp_physics_DIR} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    execute_process(COMMAND git clone --recursive https://github.com/Bbakernoaa/ccpp-physics.git ${ccpp_physics_DIR}
                    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endif()

# Set mock CCPP variables to satisfy ccpp-physics
# We use a dummy suite XML if it doesn't exist
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/suite_dummy.xml")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/suite_dummy.xml" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<suite name=\"dummy\" lib=\"ccpp_physics\" >\n</suite>\n")
endif()

# Set CCPP variables but avoid quoting issues
set(CCPP_TYPEDEFS "")
set(CCPP_SCHEMES "")
set(CCPP_CAPS "")

set(ENV{CCPP_TYPEDEFS} "")
set(ENV{CCPP_SCHEMES} "")
set(ENV{CCPP_CAPS} "")

# Run the patch script again to ensure it takes effect if files were redownloaded
execute_process(COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/patch_dependencies.py ${cdeps_SOURCE_DIR} ${ccpp_physics_DIR})

add_subdirectory(src/ccpp-framework)
target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_framework)

add_subdirectory(src/ccpp-physics)
target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_physics)
