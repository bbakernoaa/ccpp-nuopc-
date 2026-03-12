#!/usr/bin/env python

HOST_MODEL_IDENTIFIER = "CCPP-NUOPC"

VARIABLE_DEFINITION_FILES = [
    'src/ccpp-framework/src/ccpp_types.F90',
    'src/ccpp_internal_state.F90',
    'src/ccpp_data_mod.F90',
    ]

TYPEDEFS_NEW_METADATA = {
    'ccpp_types' : {
        'ccpp_types' : '',
        'ccpp_t' : 'cdata',
        },
    }

SCHEME_FILES = [
    'src/sample_scheme.F90',
    ]

DEFAULT_BUILD_DIR = 'build'

TYPEDEFS_MAKEFILE   = '{build_dir}/CCPP_TYPEDEFS.mk'
TYPEDEFS_CMAKEFILE  = '{build_dir}/CCPP_TYPEDEFS.cmake'
TYPEDEFS_SOURCEFILE = '{build_dir}/CCPP_TYPEDEFS.sh'

SCHEMES_MAKEFILE   = '{build_dir}/CCPP_SCHEMES.mk'
SCHEMES_CMAKEFILE  = '{build_dir}/CCPP_SCHEMES.cmake'
SCHEMES_SOURCEFILE = '{build_dir}/CCPP_SCHEMES.sh'

CAPS_MAKEFILE   = '{build_dir}/CCPP_CAPS.mk'
CAPS_CMAKEFILE  = '{build_dir}/CCPP_CAPS.cmake'
CAPS_SOURCEFILE = '{build_dir}/CCPP_CAPS.sh'

CAPS_DIR = '{build_dir}'

SUITES_DIR = 'src'

OPTIONAL_ARGUMENTS = {}

STATIC_API_DIR = '{build_dir}'
STATIC_API_CMAKEFILE  = '{build_dir}/CCPP_API.cmake'
STATIC_API_SOURCEFILE = '{build_dir}/CCPP_API.sh'

METADATA_HTML_OUTPUT_DIR = '{build_dir}'
HTML_VARTABLE_FILE = '{build_dir}/CCPP_VARIABLES.html'
LATEX_VARTABLE_FILE = '{build_dir}/CCPP_VARIABLES.tex'
