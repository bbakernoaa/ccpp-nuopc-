module CCPP_NUOPC_Cap
  use ESMF
  use NUOPC
  use NUOPC_Model, modelSS => SetServices
  use, intrinsic :: iso_c_binding
  use ccpp_internal_state_mod
  implicit none

  public SetServices

contains

  subroutine SetServices(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc

    rc = ESMF_SUCCESS

    ! Register NUOPC specialized methods
    call NUOPC_CompDerive(gcomp, modelSS, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call NUOPC_CompSpecialize(gcomp, specLabel=label_Advertise, &
      specRoutine=Advertise, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call NUOPC_CompSpecialize(gcomp, specLabel=label_RealizeProvided, &
      specRoutine=Realize, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call NUOPC_CompSpecialize(gcomp, specLabel=label_DataInitialize, &
      specRoutine=DataInitialize, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call NUOPC_CompSpecialize(gcomp, specLabel=label_Advance, &
      specRoutine=ModelAdvance, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call NUOPC_CompSpecialize(gcomp, specLabel=label_Finalize, &
      specRoutine=Finalize, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

  end subroutine SetServices

  subroutine Advertise(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc

    type(ESMF_State) :: importState, exportState
    type(ccpp_internal_state_type), pointer :: state

    rc = ESMF_SUCCESS

    ! Allocate and set internal state
    allocate(state)
    state%ncol = 100_c_int
    state%nlev = 50_c_int
    call ESMF_GridCompSetInternalState(gcomp, state, rc=rc)

    call NUOPC_ModelGet(gcomp, importState=importState, exportState=exportState, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call NUOPC_Advertise(importState, StandardName="air_temperature", rc=rc)
    call NUOPC_Advertise(importState, StandardName="air_pressure", rc=rc)
    call NUOPC_Advertise(exportState, StandardName="specific_humidity", rc=rc)
    call NUOPC_Advertise(exportState, StandardName="precipitation_rate", rc=rc)

  end subroutine Advertise

  subroutine Realize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc

    type(ccpp_internal_state_type), pointer :: state
    type(ESMF_State) :: importState, exportState
    type(ESMF_Field) :: field
    integer :: counts(2)
    integer(c_int) :: ccpp_rc

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Create grid
    counts = (/ int(state%ncol), int(state%nlev) /)
    state%grid = ESMF_GridCreate(maxIndex=counts, rc=rc)

    call NUOPC_ModelGet(gcomp, importState=importState, exportState=exportState, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="air_temperature", rc=rc)
    call NUOPC_Realize(importState, field=field, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="air_pressure", rc=rc)
    call NUOPC_Realize(importState, field=field, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="specific_humidity", rc=rc)
    call NUOPC_Realize(exportState, field=field, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="precipitation_rate", rc=rc)
    call NUOPC_Realize(exportState, field=field, rc=rc)

    ! Initialize CCPP framework
    call ccpp_init(state%ccpp_state, "my_physics_suite", ccpp_rc)

  end subroutine Realize

  subroutine DataInitialize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc
    rc = ESMF_SUCCESS
  end subroutine DataInitialize

  subroutine ModelAdvance(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc

    type(ccpp_internal_state_type), pointer :: state
    type(ESMF_State) :: importState, exportState
    type(ESMF_Clock) :: clock
    type(ESMF_Field) :: field
    integer(c_int) :: ccpp_rc

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
    call ESMF_GridCompGet(gcomp, importState=importState, exportState=exportState, clock=clock, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! 1. PRE-RUN: Map fields and Register with CCPP
    call ccpp_field_add(state%ccpp_state, "horizontal_loop_extent", state%ncol, ccpp_rc)
    call ccpp_field_add(state%ccpp_state, "vertical_dimension", state%nlev, ccpp_rc)

    call ESMF_StateGet(importState, "air_temperature", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
    call ESMF_FieldGet(field, farrayPtr=state%temp, rc=rc)
    call ccpp_field_add(state%ccpp_state, "air_temperature", state%temp, ccpp_rc)

    call ESMF_StateGet(importState, "air_pressure", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
    call ESMF_FieldGet(field, farrayPtr=state%pres, rc=rc)
    call ccpp_field_add(state%ccpp_state, "air_pressure", state%pres, ccpp_rc)

    call ESMF_StateGet(exportState, "specific_humidity", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
    call ESMF_FieldGet(field, farrayPtr=state%q, rc=rc)
    call ccpp_field_add(state%ccpp_state, "specific_humidity", state%q, ccpp_rc)

    call ESMF_StateGet(exportState, "precipitation_rate", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
    call ESMF_FieldGet(field, farrayPtr=state%rain, rc=rc)
    call ccpp_field_add(state%ccpp_state, "precipitation_rate", state%rain, ccpp_rc)

    ! 2. Execute CCPP Run
    call ccpp_run(state%ccpp_state, "my_physics_suite", ccpp_rc)
    if (ccpp_rc /= 0_c_int) then
      rc = ESMF_FAILURE
      return
    end if

  end subroutine ModelAdvance

  subroutine Finalize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc
    type(ccpp_internal_state_type), pointer :: state
    integer(c_int) :: ccpp_rc

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call ccpp_finalize(state%ccpp_state, ccpp_rc)
    call ESMF_GridDestroy(state%grid, rc=rc)
    deallocate(state)
  end subroutine Finalize

end module CCPP_NUOPC_Cap
