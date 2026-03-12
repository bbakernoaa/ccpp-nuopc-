module ccpp_data_mod
  use ccpp_internal_state_mod, only: ccpp_internal_state_type
#ifdef USE_REAL_CCPP
  use ccpp_types, only: ccpp_t
#else
  use ccpp_internal_state_mod, only: ccpp_t
#endif
  implicit none
  private
  public :: state, cdata

!> \section arg_table_ccpp_data_mod Argument Table
!! \htmlinclude ccpp_data_mod.html
!!

  ! Pointer to the internal state instance currently being processed
  ! This allows CCPP to access variables via 'state%var'
  type(ccpp_internal_state_type), pointer :: state => null()

  ! Global ccpp_t handle pointer
  type(ccpp_t), pointer :: cdata => null()

end module ccpp_data_mod
