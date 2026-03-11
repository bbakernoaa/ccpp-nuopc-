module ccpp_driver_mod
  use ESMF
  use NUOPC
  use, intrinsic :: iso_c_binding
  use ccpp_internal_state_mod
  use ccpp_data_mod
#ifdef USE_REAL_CCPP
  use ccpp_static_api
  use ccpp_types, only: ccpp_init, ccpp_finalize
#endif
  implicit none

  private
  public :: ccpp_driver_init
  public :: ccpp_driver_run
  public :: ccpp_driver_finalize

contains

  subroutine ccpp_driver_init(gcomp, suite_name, rc)
    type(ESMF_GridComp), intent(inout) :: gcomp
    character(*), intent(in)           :: suite_name
    integer, intent(out)               :: rc

    type(ccpp_internal_state_type), pointer :: istate
    integer(kind_int) :: ierr

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, istate, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Set module-level pointer
    state => istate
    cdata => state%ccpp_state

    ! Initialize CCPP handle and suite
    call ccpp_init(cdata, suite_name, ierr)
    if (ierr /= 0_kind_int) then
       rc = ESMF_FAILURE
       return
    end if

    ! Initialize physics schemes for the suite
    call ccpp_physics_init(cdata, suite_name=suite_name, ierr=ierr)
    if (ierr /= 0_kind_int) then
       rc = ESMF_FAILURE
       return
    end if

  end subroutine ccpp_driver_init

  subroutine ccpp_driver_run(gcomp, importState, exportState, suite_name, group_name, rc)
    type(ESMF_GridComp), intent(inout) :: gcomp
    type(ESMF_State), intent(in)       :: importState
    type(ESMF_State), intent(inout)    :: exportState
    character(*), intent(in)           :: suite_name
    character(*), intent(in)           :: group_name
    integer, intent(out)               :: rc

    type(ccpp_internal_state_type), pointer :: istate
    type(ESMF_Field) :: field
    integer(kind_int) :: ierr

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, istate, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Set module-level pointer for the framework to access via 'state%var'
    state => istate
    cdata => state%ccpp_state

    ! Unified interface: Ingest ESMF importState AND exportState fields
    ! MANDATORY: All pointers must be mapped BEFORE physics run

    ! Import fields
    call ESMF_StateGet(importState, "air_temperature", field, rc=rc)
    if (rc == ESMF_SUCCESS) call ESMF_FieldGet(field, farrayPtr=state%temp, rc=rc)

    call ESMF_StateGet(importState, "air_pressure", field, rc=rc)
    if (rc == ESMF_SUCCESS) call ESMF_FieldGet(field, farrayPtr=state%pres, rc=rc)

    ! Export fields (pre-mapping memory for physics to write into)
    call ESMF_StateGet(exportState, "specific_humidity", field, rc=rc)
    if (rc == ESMF_SUCCESS) call ESMF_FieldGet(field, farrayPtr=state%q, rc=rc)

    call ESMF_StateGet(exportState, "precipitation_rate", field, rc=rc)
    if (rc == ESMF_SUCCESS) call ESMF_FieldGet(field, farrayPtr=state%rain, rc=rc)

    ! Execute CCPP via the static API
    call ccpp_physics_timestep_init(cdata, suite_name=suite_name, group_name=group_name, ierr=ierr)
    if (ierr == 0_kind_int) then
       call ccpp_physics_run(cdata, suite_name=suite_name, group_name=group_name, ierr=ierr)
    end if
    if (ierr == 0_kind_int) then
       call ccpp_physics_timestep_finalize(cdata, suite_name=suite_name, group_name=group_name, ierr=ierr)
    end if

    if (ierr /= 0_kind_int) then
       rc = ESMF_FAILURE
       return
    end if

  end subroutine ccpp_driver_run

  subroutine ccpp_driver_finalize(gcomp, suite_name, rc)
    type(ESMF_GridComp), intent(inout) :: gcomp
    character(*), intent(in)           :: suite_name
    integer, intent(out)               :: rc

    type(ccpp_internal_state_type), pointer :: istate
    integer(kind_int) :: ierr

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, istate, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    state => istate
    cdata => state%ccpp_state

    ! Finalize physics and CCPP framework
    call ccpp_physics_finalize(cdata, suite_name=suite_name, ierr=ierr)
    call ccpp_finalize(cdata, ierr)

  end subroutine ccpp_driver_finalize

end module ccpp_driver_mod
