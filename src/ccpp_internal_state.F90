module ccpp_internal_state_mod
  use ESMF
  use, intrinsic :: iso_c_binding
#ifdef USE_REAL_CCPP
  use ccpp_types, only: ccpp_t
#endif
  implicit none

  ! Kind parameters for CCPP consistency
  integer, parameter :: kind_phys = c_double
  integer, parameter :: kind_int  = c_int

#ifndef USE_REAL_CCPP
  type ccpp_t
     integer(kind_int)    :: errflg
     character(len=512)   :: errmsg
     integer(kind_int)    :: blk_no
     integer(kind_int)    :: thrd_no
     integer(kind_int)    :: loop_cnt
     integer(kind_int)    :: loop_max
  end type ccpp_t
#endif

  type ccpp_internal_state_type
    ! ESMF-related
    type(ESMF_Grid) :: grid
    type(ESMF_Mesh) :: mesh

    ! Data arrays (pointers to ESMF field memory)
    real(kind_phys), pointer :: temp(:,:) => null()
    real(kind_phys), pointer :: pres(:,:) => null()
    real(kind_phys), pointer :: q(:,:) => null()

    ! Diagnostic Export
    real(kind_phys), pointer :: rain(:,:) => null()

    ! Dimensions
    integer(kind_int) :: ncol, nlev
    integer(kind_int) :: ncol_all ! for horizontal_dimension

    ! CCPP internal state handle
    type(ccpp_t) :: ccpp_state

  end type ccpp_internal_state_type

#ifndef USE_REAL_CCPP
contains
  subroutine ccpp_init(ccpp_state, suite, rc)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite
    integer(kind_int), intent(out) :: rc
    ccpp_state%errflg = 0_kind_int
    ccpp_state%errmsg = ""
    ccpp_state%blk_no = 1_kind_int
    ccpp_state%thrd_no = 1_kind_int
    ccpp_state%loop_cnt = 1_kind_int
    ccpp_state%loop_max = 1_kind_int
    rc = 0_kind_int
  end subroutine ccpp_init

  subroutine ccpp_physics_init(ccpp_state, suite_name, group_name, ierr)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite_name
    character(*), intent(in), optional :: group_name
    integer(kind_int), intent(out) :: ierr
    ccpp_state%errflg = 0_kind_int
    ccpp_state%errmsg = ""
    ierr = 0_kind_int
  end subroutine ccpp_physics_init

  subroutine ccpp_physics_timestep_init(ccpp_state, suite_name, group_name, ierr)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite_name
    character(*), intent(in), optional :: group_name
    integer(kind_int), intent(out) :: ierr
    ierr = 0_kind_int
  end subroutine ccpp_physics_timestep_init

  subroutine ccpp_physics_run(ccpp_state, suite_name, group_name, ierr)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite_name
    character(*), intent(in), optional :: group_name
    integer(kind_int), intent(out) :: ierr
    ierr = 0_kind_int
  end subroutine ccpp_physics_run

  subroutine ccpp_physics_timestep_finalize(ccpp_state, suite_name, group_name, ierr)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite_name
    character(*), intent(in), optional :: group_name
    integer(kind_int), intent(out) :: ierr
    ierr = 0_kind_int
  end subroutine ccpp_physics_timestep_finalize

  subroutine ccpp_physics_finalize(ccpp_state, suite_name, group_name, ierr)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: suite_name
    character(*), intent(in), optional :: group_name
    integer(kind_int), intent(out) :: ierr
    ierr = 0_kind_int
  end subroutine ccpp_physics_finalize

  subroutine ccpp_finalize(ccpp_state, rc)
    type(ccpp_t), intent(inout) :: ccpp_state
    integer(kind_int), intent(out) :: rc
    rc = 0_kind_int
  end subroutine ccpp_finalize

  subroutine ccpp_field_add(ccpp_state, name, var, rc)
    type(ccpp_t), intent(inout) :: ccpp_state
    character(*), intent(in)    :: name
    class(*), pointer, intent(in) :: var
    integer(kind_int), intent(out) :: rc
    rc = 0_kind_int
  end subroutine ccpp_field_add
#endif

end module ccpp_internal_state_mod
