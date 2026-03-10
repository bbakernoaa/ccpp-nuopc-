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
    GIT_REPOSITORY https://github.com/ESCOMP/CDEPS
    GIT_TAG        v0.12.0 # Pinning to a stable release
)
FetchContent_MakeAvailable(cdeps)

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
