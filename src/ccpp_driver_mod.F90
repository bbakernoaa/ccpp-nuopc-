module ccpp_driver_mod
#ifdef USE_REAL_CCPP
  use ESMF
  use NUOPC
#endif
  use, intrinsic :: iso_c_binding
  use ccpp_internal_state_mod
  use ccpp_data_mod
#ifdef USE_REAL_CCPP
  use ccpp_static_api
#endif
  implicit none

  private
  public :: ccpp_driver_init
  public :: ccpp_driver_run
  public :: ccpp_driver_finalize

contains

  subroutine ccpp_driver_init(gcomp, suite_name, rc)
#ifdef USE_REAL_CCPP
    type(ESMF_GridComp), intent(inout) :: gcomp
#else
    integer, intent(inout)             :: gcomp
#endif
    character(*), intent(in)           :: suite_name
    integer, intent(out)               :: rc

    type(ccpp_internal_state_type), pointer :: istate => null()
    integer(kind_int) :: ierr

    rc = 0
#ifdef USE_REAL_CCPP
    call ESMF_GridCompGetInternalState(gcomp, istate, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
#endif

    ! Set module-level pointer
    if (associated(istate)) then
       state => istate
       cdata => state%ccpp_state
    else
       ! In mock mode, we assume 'state' is already set by the test or caller
       if (.not. associated(state)) then
          rc = 1
          return
       end if
       cdata => state%ccpp_state
    end if

    ! Initialize CCPP handle and suite
    call ccpp_init(cdata, suite_name, ierr)
    if (ierr /= 0_kind_int) then
#ifdef USE_REAL_CCPP
       rc = ESMF_FAILURE
#else
       rc = 1
#endif
       return
    end if

    ! Initialize physics schemes for the suite
    call ccpp_physics_init(cdata, suite_name=suite_name, ierr=ierr)
    if (ierr /= 0_kind_int) then
#ifdef USE_REAL_CCPP
       rc = ESMF_FAILURE
#else
       rc = 1
#endif
       return
    end if

  end subroutine ccpp_driver_init

  subroutine ccpp_driver_run(gcomp, importState, exportState, suite_name, group_name, rc)
#ifdef USE_REAL_CCPP
    type(ESMF_GridComp), intent(inout) :: gcomp
    type(ESMF_State), intent(in)       :: importState
    type(ESMF_State), intent(inout)    :: exportState
#else
    integer, intent(inout)             :: gcomp
    integer, intent(in)                :: importState
    integer, intent(inout)             :: exportState
#endif
    character(*), intent(in)           :: suite_name
    character(*), intent(in)           :: group_name
    integer, intent(out)               :: rc

    type(ccpp_internal_state_type), pointer :: istate => null()
#ifdef USE_REAL_CCPP
    type(ESMF_Field) :: field
#endif
    integer(kind_int) :: ierr

    rc = 0
#ifdef USE_REAL_CCPP
    call ESMF_GridCompGetInternalState(gcomp, istate, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
#endif

    ! Set module-level pointer for the framework to access via 'state%var'
    if (associated(istate)) then
       state => istate
       cdata => state%ccpp_state
    else
       if (.not. associated(state)) then
          rc = 1
          return
       end if
       cdata => state%ccpp_state
    end if

    ! Unified interface: Ingest ESMF importState AND exportState fields
    ! MANDATORY: All pointers must be mapped BEFORE physics run

#ifdef USE_REAL_CCPP
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
#endif

    ! Execute CCPP via the static API
    call ccpp_physics_timestep_init(cdata, suite_name=suite_name, group_name=group_name, ierr=ierr)
    if (ierr == 0_kind_int) then
       call ccpp_physics_run(cdata, suite_name=suite_name, group_name=group_name, ierr=ierr)
    end if
    if (ierr == 0_kind_int) then
       call ccpp_physics_timestep_finalize(cdata, suite_name=suite_name, group_name=group_name, ierr=ierr)
    end if

    if (ierr /= 0_kind_int) then
#ifdef USE_REAL_CCPP
       rc = ESMF_FAILURE
#else
       rc = 1
#endif
       return
    end if

  end subroutine ccpp_driver_run

  subroutine ccpp_driver_finalize(gcomp, suite_name, rc)
#ifdef USE_REAL_CCPP
    type(ESMF_GridComp), intent(inout) :: gcomp
#else
    integer, intent(inout)             :: gcomp
#endif
    character(*), intent(in)           :: suite_name
    integer, intent(out)               :: rc

    type(ccpp_internal_state_type), pointer :: istate => null()
    integer(kind_int) :: ierr

    rc = 0
#ifdef USE_REAL_CCPP
    call ESMF_GridCompGetInternalState(gcomp, istate, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
#endif

    if (associated(istate)) then
       state => istate
       cdata => state%ccpp_state
    else
       if (.not. associated(state)) then
          rc = 1
          return
       end if
       cdata => state%ccpp_state
    end if

    ! Finalize physics and CCPP framework
    call ccpp_physics_finalize(cdata, suite_name=suite_name, ierr=ierr)
    call ccpp_finalize(cdata, ierr)

  end subroutine ccpp_driver_finalize

end module ccpp_driver_mod
