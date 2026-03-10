cmake_minimum_required(VERSION 3.15)
project(ccpp-nuopc LANGUAGES Fortran)

# Add cmake directory to module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Find ESMF
find_package(ESMF REQUIRED)

# Find OpenMP
find_package(OpenMP REQUIRED)

# Add CDEPS via FetchContent
include(FetchContent)
FetchContent_Declare(
    cdeps
    GIT_REPOSITORY https://github.com/NOAA-EMC/CDEPS
    GIT_TAG        cdeps0.4.17 # Pinning to a stable release
    GIT_SUBMODULES_RECURSIVE ON
)

FetchContent_GetProperties(cdeps)
if(NOT cdeps_POPULATED)
    FetchContent_Populate(cdeps)

    # Use ESMFMKFILE to find PIO if available in the environment
    if(DEFINED ENV{ESMFMKFILE} AND NOT PIO_PATH)
        execute_process(COMMAND grep "ESMF_PIO_INCLUDE" $ENV{ESMFMKFILE}
                        COMMAND cut -d= -f2
                        OUTPUT_VARIABLE PIO_INC_DIR
                        OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(PIO_INC_DIR)
            # Remove possible -I prefix if grep caught the whole line
            string(REPLACE "-I" "" PIO_INC_DIR "${PIO_INC_DIR}")
            string(STRIP "${PIO_INC_DIR}" PIO_INC_DIR)
            get_filename_component(PIO_ROOT "${PIO_INC_DIR}" DIRECTORY)
            set(PIO_PATH "${PIO_ROOT}" CACHE PATH "PIO installation path")
            message(STATUS "Derived PIO_PATH from ESMFMKFILE: ${PIO_PATH}")
        endif()
    endif()

    # Add CDEPS cmake directory to module path for finding PIO
    list(APPEND CMAKE_MODULE_PATH "${cdeps_SOURCE_DIR}/cmake")
    add_subdirectory(${cdeps_SOURCE_DIR} ${cdeps_BINARY_DIR})
endif()

# Add internal state library
add_library(ccpp_internal_state src/ccpp_internal_state.F90)
target_link_libraries(ccpp_internal_state PUBLIC ESMF::ESMF)
target_include_directories(ccpp_internal_state PUBLIC ${CMAKE_CURRENT_BINARY_DIR})

# Add NUOPC cap library
add_library(ccpp_nuopc_cap src/ccpp_nuopc_cap.F90 src/ccpp_inline_cdeps_mod.F90)
target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_internal_state ESMF::ESMF cdeps OpenMP::OpenMP_Fortran)

# Prepare for CCPP submodules
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-framework/CMakeLists.txt")
    add_subdirectory(src/ccpp-framework)
    target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_framework)
endif()
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/ccpp-physics/CMakeLists.txt")
    add_subdirectory(src/ccpp-physics)
    target_link_libraries(ccpp_nuopc_cap PUBLIC ccpp_physics)
endif()
