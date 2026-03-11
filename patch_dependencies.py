import re
import sys
import os

def patch_cdeps(cdeps_src):
    print(f"Patching CDEPS in {cdeps_src}")
    for root, dirs, files in os.walk(cdeps_src):
        for name in files:
            if name == 'CMakeLists.txt' or name.endswith('.cmake'):
                fpath = os.path.join(root, name)
                with open(fpath, 'r') as f:
                    content = f.read()

                # Comment out install() blocks
                content = re.sub(r'install\s*\((.*?)\)',
                                 lambda m: '#install(' + '\n'.join(['#' + l for l in m.group(1).split('\n')]) + ')',
                                 content, flags=re.DOTALL|re.IGNORECASE)

                # Comment out find_package(PIO ...)
                content = re.sub(r'find_package\s*\(PIO.*?\)', '#find_package(PIO)', content, flags=re.DOTALL|re.IGNORECASE)

                # Fix endforeach/endif legacy syntax
                content = re.sub(r'endforeach\s*\([A-Za-z0-9_]+\)', 'endforeach()', content, flags=re.IGNORECASE)
                content = re.sub(r'endif\s*\([A-Za-z0-9_]+\)', 'endif()', content, flags=re.IGNORECASE)

                # Replace usage of ESMF_F90COMPILEPATHS with ESMF_INCLUDE_DIRS
                content = content.replace('${ESMF_F90COMPILEPATHS}', '${ESMF_INCLUDE_DIRS}')

                with open(fpath, 'w') as f:
                    f.write(content)

    # Special patch for main CMakeLists.txt
    main_cmake = os.path.join(cdeps_src, 'CMakeLists.txt')
    if os.path.exists(main_cmake):
        with open(main_cmake, 'r') as f:
            content = f.read()
        content = content.replace('add_subdirectory(fox)', '#add_subdirectory(fox)')
        content = content.replace('find_package(ESMF REQUIRED)', '#find_package(ESMF REQUIRED)')

        # Ensure ESMF::ESMF is linked to all targets
        content = content.replace('target_link_libraries(${COMP} PUBLIC', 'target_link_libraries(${COMP} PUBLIC ESMF::ESMF')
        content = content.replace('target_link_libraries(streams PUBLIC', 'target_link_libraries(streams PUBLIC ESMF::ESMF')
        content = content.replace('target_link_libraries(dshr PUBLIC', 'target_link_libraries(dshr PUBLIC ESMF::ESMF')

        with open(main_cmake, 'w') as f:
            f.write(content)

    # Patch share/CMakeLists.txt to link ESMF
    share_cmake = os.path.join(cdeps_src, 'share', 'CMakeLists.txt')
    if os.path.exists(share_cmake):
        with open(share_cmake, 'r') as f:
            content = f.read()
        if 'target_link_libraries(cdeps_share' not in content:
            content += '\ntarget_link_libraries(cdeps_share PUBLIC ESMF::ESMF)\n'
        with open(share_cmake, 'w') as f:
            f.write(content)

    # Patch streams/CMakeLists.txt to link ESMF
    streams_cmake = os.path.join(cdeps_src, 'streams', 'CMakeLists.txt')
    if os.path.exists(streams_cmake):
        with open(streams_cmake, 'r') as f:
            content = f.read()
        if 'target_link_libraries(streams' not in content:
            content += '\ntarget_link_libraries(streams PUBLIC ESMF::ESMF)\n'
        with open(streams_cmake, 'w') as f:
            f.write(content)

    # Patch dshr/CMakeLists.txt to link ESMF
    dshr_cmake = os.path.join(cdeps_src, 'dshr', 'CMakeLists.txt')
    if os.path.exists(dshr_cmake):
        with open(dshr_cmake, 'r') as f:
            content = f.read()
        if 'target_link_libraries(dshr' not in content:
            content += '\ntarget_link_libraries(dshr PUBLIC ESMF::ESMF)\n'
        with open(dshr_cmake, 'w') as f:
            f.write(content)

    # Patch each component subdirectory to link ESMF
    for comp in ['datm', 'dice', 'dglc', 'dlnd', 'docn', 'drof', 'dwav']:
        comp_cmake = os.path.join(cdeps_src, comp, 'CMakeLists.txt')
        if os.path.exists(comp_cmake):
            with open(comp_cmake, 'r') as f:
                content = f.read()
            if f'target_link_libraries({comp}' not in content:
                content += f'\ntarget_link_libraries({comp} PUBLIC ESMF::ESMF)\n'
            elif 'ESMF::ESMF' not in content:
                content = content.replace(f'target_link_libraries({comp}', f'target_link_libraries({comp} PUBLIC ESMF::ESMF ')
            with open(comp_cmake, 'w') as f:
                f.write(content)

def patch_ccpp_physics(physics_src):
    print(f"Patching CCPP Physics in {physics_src}")
    main_cmake = os.path.join(physics_src, 'CMakeLists.txt')
    if os.path.exists(main_cmake):
        with open(main_cmake, 'r') as f:
            content = f.read()

        # Remove NCEPLIBS and NetCDF dependencies
        pattern = r'target_link_libraries\s*\(ccpp_physics PUBLIC(.*?)\)'
        content = re.sub(pattern, 'target_link_libraries(ccpp_physics PUBLIC)', content, flags=re.DOTALL)

        # Fix add_library(ccpp_physics STATIC ...)
        dummy_file = os.path.join(physics_src, 'ccpp_dummy.F90')
        if not os.path.exists(dummy_file):
            with open(dummy_file, 'w') as f:
                f.write('module ccpp_dummy\nend module ccpp_dummy\n')

        content = re.sub(r'add_library\s*\(ccpp_physics STATIC.*?\)',
                         'add_library(ccpp_physics STATIC ccpp_dummy.F90)',
                         content, flags=re.DOTALL)

        # Handle TYPEDEFS/SCHEMES/CAPS include issues
        content = content.replace('include(${CMAKE_CURRENT_BINARY_DIR}/CCPP_TYPEDEFS.cmake)', '#include TYPEDEFS')
        content = content.replace('include(${CMAKE_CURRENT_BINARY_DIR}/CCPP_SCHEMES.cmake)', '#include SCHEMES')
        content = content.replace('include(${CMAKE_CURRENT_BINARY_DIR}/CCPP_CAPS.cmake)', '#include CAPS')

        with open(main_cmake, 'w') as f:
            f.write(content)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: patch_dependencies.py <cdeps_src> <physics_src>")
        sys.exit(1)
    patch_cdeps(sys.argv[1])
    patch_ccpp_physics(sys.argv[2])
