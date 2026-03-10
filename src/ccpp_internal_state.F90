module ccpp_internal_state_mod
  use ESMF
  use, intrinsic :: iso_c_binding
  ! In a real integration, we would use the actual CCPP modules:
  ! use ccpp_types, only: ccpp_t
  implicit none

  ! Placeholder for ccpp_t if the library is not yet compiled/linked
  type ccpp_t
     integer(c_int) :: dummy
  end type ccpp_t

  type ccpp_internal_state_type
    ! ESMF-related
    type(ESMF_Grid) :: grid

    ! Data arrays (pointers to ESMF field memory)
    ! Using c_double for consistency with CCPP requirements
    real(c_double), pointer :: temp(:,:) => null()
    real(c_double), pointer :: pres(:,:) => null()
    real(c_double), pointer :: q(:,:) => null()
    real(c_double), pointer :: rain(:,:) => null()

    ! Dimensions
    integer(c_int) :: ncol, nlev

    ! CCPP internal state handle
    type(ccpp_t) :: ccpp_state

  end type ccpp_internal_state_type

end module ccpp_internal_state_mod
