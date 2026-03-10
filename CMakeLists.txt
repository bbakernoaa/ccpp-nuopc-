cmake_minimum_required(VERSION 3.15)
project(ccpp-nuopc LANGUAGES Fortran)

# Add cmake directory to module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Find ESMF
find_package(ESMF REQUIRED)

# Find OpenMP
find_package(OpenMP REQUIRED)

# Check if CDEPS is already available (e.g. via Spack)
find_package(CDEPS QUIET)

if(NOT CDEPS_FOUND)
    message(STATUS "CDEPS not found on system, attempting to build from source using FetchContent...")

    # Discovery PIO and NetCDF from ESMF if possible
    function(find_root_by_file root_var filename)
        if(NOT ${root_var})
            foreach(lib ${ESMF_LIBRARIES})
                if(lib MATCHES "^-L(.*)")
                    set(search_path "${CMAKE_MATCH_1}")
                    if(EXISTS "${search_path}/../include/${filename}")
                        set(root "${search_path}/..")
                        get_filename_component(root "${root}" ABSOLUTE)
                        set(${root_var} "${root}" PARENT_SCOPE)
                        message(STATUS "Found ${root_var} from ESMF path: ${root}")
                        return()
                    endif()
                endif()
            endforeach()
        endif()
    endfunction()

    find_root_by_file(PIO_ROOT "pio.h")

    if(PIO_ROOT)
        set(PIO_FOUND TRUE)
        set(PIO_PATH "${PIO_ROOT}")
        set(ENV{PIO_PATH} "${PIO_ROOT}")
        set(ENV{PIO_ROOT} "${PIO_ROOT}")
    endif()

    # Fallback to FetchContent if not found in the environment
    include(FetchContent)
    FetchContent_Declare(
        cdeps
        GIT_REPOSITORY https://github.com/bbakernoaa/CDEPS.git
        GIT_TAG        ae5d2c457321ebae3a0d9c9c949f871bb8f2b09c
        GIT_SUBMODULES_RECURSIVE ON
        PATCH_COMMAND bash -c " \
            sed -i 's/add_subdirectory(fox)/#add_subdirectory(fox)/' CMakeLists.txt; \
            find . -name CMakeLists.txt -exec sed -i 's/install(/#install(/g' {} +; \
        "
    )

    # Force CDEPS flags
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -ffree-line-length-none -DCPRGNU" CACHE STRING "Fortran flags" FORCE)
    set(DISABLE_FoX ON CACHE BOOL "Disable FoX library" FORCE)
    set(COMPILER "gnu" CACHE STRING "Compiler type")

    FetchContent_MakeAvailable(cdeps)

    if(TARGET dshr)
        set(CDEPS_FOUND TRUE)
        # Ensure CDEPS can find ESMF modules
        target_include_directories(streams PRIVATE ${ESMF_INCLUDE_DIRS})
        target_include_directories(dshr PRIVATE ${ESMF_INCLUDE_DIRS})
        target_include_directories(cdeps_share PRIVATE ${ESMF_INCLUDE_DIRS})
    endif()

    # Ensure FindPIO.cmake from CDEPS is available
    list(APPEND CMAKE_MODULE_PATH "${cdeps_SOURCE_DIR}/cmake")
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
