# CCPP-NUOPC Cap with Unified CCPP Driver

This repository provides a NUOPC-compliant cap for the Common Community Physics Package (CCPP), featuring a unified driver interface that simplifies the integration between ESMF states and CCPP suites. It mirrors the design patterns found in the UFSATM repository but provides a streamlined interface for generic use.

## Design

The implementation is centered around three main components:

1.  **Unified Driver (`src/ccpp_driver_mod.F90`)**: This module provides high-level subroutines (`ccpp_driver_init`, `ccpp_driver_run`, `ccpp_driver_finalize`) to manage CCPP execution. It handles the mapping of ESMF fields from `importState` and `exportState` to the internal CCPP data structures.
2.  **Internal State (`src/ccpp_internal_state.F90`)**: A data container that holds pointers to the model fields and the CCPP state handle (`ccpp_t`).
3.  **NUOPC Cap (`src/ccpp_nuopc_cap.F90`)**: The ESMF/NUOPC interface that implements the standard `SetServices`, `Advertise`, `Realize`, and `ModelAdvance` methods, delegating CCPP-specific logic to the unified driver.

## Configuration

### CCPP Suites

CCPP suites are defined in XML files located in the `src/` directory (e.g., `src/my_physics_suite.xml`). These files specify which physics schemes are executed and in what order.

### Metadata

Each scheme and the host model must have associated `.meta` files (e.g., `src/sample_scheme.meta`, `src/ccpp_nuopc_cap.meta`) that define the variables provided to or requested by CCPP.

## Building and Running

The project uses CMake and requires an environment with ESMF, MPI, and CCPP dependencies (NetCDF, PIO, etc.). The JCSDA Docker image is recommended for a consistent build environment.

### Build Steps

1.  **Generate Static API**: The `ccpp_prebuild.py` script is used to generate the static API and caps based on the suite definition and metadata.
2.  **Compile**:
    ```bash
    mkdir build
    cd build
    cmake ..
    make
    ```

### Running the Unit Test

A basic unit test is provided to verify the integration:
```bash
./test_ccpp_driver
```

## Adding New Schemes

To add a new physics scheme:
1.  Place the Fortran source in `src/`.
2.  Create a corresponding `.meta` file in `src/`.
3.  Add the scheme to `SCHEME_FILES` in `ccpp_prebuild_config.py`.
4.  Include the scheme in your suite XML file.
