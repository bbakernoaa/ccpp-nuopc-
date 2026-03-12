program test_ccpp_driver
  use, intrinsic :: iso_c_binding
  use ccpp_internal_state_mod
  use ccpp_driver_mod
  implicit none

  integer :: rc
  integer :: gcomp = 0
  integer :: importState = 0
  integer :: exportState = 0
  type(ccpp_internal_state_type), pointer :: state

  print *, "CCPP Driver unit test starting..."

  ! Initialize internal state
  allocate(state)
  state%ncol = 10
  state%nlev = 20

  ! In mock mode, we manually set the global pointer that the driver expects
  ! Normally this is done in the Advertise/Realize phase of the cap
  call test_init_ccpp_data(state)

  ! Test Driver Init
  call ccpp_driver_init(gcomp, "my_physics_suite", rc)
  if (rc /= 0) then
     print *, "Driver Init FAILED"
     stop 1
  end if

  ! Test Driver Run
  call ccpp_driver_run(gcomp, importState, exportState, "my_physics_suite", "physics", rc)
  if (rc /= 0) then
     print *, "Driver Run FAILED"
     stop 1
  end if

  ! Test Driver Finalize
  call ccpp_driver_finalize(gcomp, "my_physics_suite", rc)
  if (rc /= 0) then
     print *, "Driver Finalize FAILED"
     stop 1
  end if

  print *, "CCPP Driver unit test PASSED"
  deallocate(state)

contains

  subroutine test_init_ccpp_data(istate)
    use ccpp_data_mod, only: state, cdata
    type(ccpp_internal_state_type), pointer :: istate
    state => istate
    cdata => istate%ccpp_state
  end subroutine test_init_ccpp_data

end program test_ccpp_driver
