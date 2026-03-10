module ccpp_internal_state_mod
  use ESMF
  use, intrinsic :: iso_c_binding
  implicit none

  ! Preprocessor-guarded mock for standalone development/CI
#ifndef USE_REAL_CCPP
  type ccpp_t
     integer(c_int) :: dummy
  end type ccpp_t
#endif

  type ccpp_internal_state_type
    ! ESMF-related
    type(ESMF_Grid) :: grid

    ! Data arrays (pointers to ESMF field memory)
    real(c_double), pointer :: temp(:,:) => null()
    real(c_double), pointer :: pres(:,:) => null()
    real(c_double), pointer :: q(:,:) => null()

    ! Diagnostic Export
    real(c_double), pointer :: rain(:,:) => null()

    ! Dimensions
    integer(c_int) :: ncol, nlev

    ! CCPP internal state handle
    type(ccpp_t) :: ccpp_state

  end type ccpp_internal_state_type

#ifndef USE_REAL_CCPP
  ! Generic interface for mock to handle different ranks
  interface ccpp_field_add
     module procedure ccpp_field_add_2d
     module procedure ccpp_field_add_scalar
  end interface

contains
  subroutine ccpp_init(ccpp_state, suite, rc)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite
    integer(c_int), intent(out) :: rc
    rc = 0_c_int
  end subroutine ccpp_init

  subroutine ccpp_field_add_2d(ccpp_state, name, var, rc)
    type(ccpp_t),  intent(inout) :: ccpp_state
    character(*),  intent(in)    :: name
    real(c_double), pointer      :: var(:,:)
    integer(c_int), intent(out)  :: rc
    rc = 0_c_int
  end subroutine ccpp_field_add_2d

  subroutine ccpp_field_add_scalar(ccpp_state, name, var, rc)
    type(ccpp_t),  intent(inout) :: ccpp_state
    character(*),  intent(in)    :: name
    integer(c_int), intent(in)   :: var
    integer(c_int), intent(out)  :: rc
    rc = 0_c_int
  end subroutine ccpp_field_add_scalar

  subroutine ccpp_run(ccpp_state, suite, rc)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite
    integer(c_int), intent(out) :: rc
    rc = 0_c_int
  end subroutine ccpp_run

  subroutine ccpp_finalize(ccpp_state, rc)
    type(ccpp_t), intent(inout) :: ccpp_state
    integer(c_int), intent(out) :: rc
    rc = 0_c_int
  end subroutine ccpp_finalize
#endif

end module ccpp_internal_state_mod
