module CCPP_NUOPC_Cap
  use ESMF
  use NUOPC
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
    call NUOPC_CompDerive(gcomp, NUOPC_SetServices, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="NUOPC_CompDerive failed")) return

    call NUOPC_CompSpecialize(gcomp, specLabel="label_InitializeP1", &
      specRoutine=InitializeP1, rc=rc)

    call NUOPC_CompSpecialize(gcomp, specLabel="label_Advertise", &
      specRoutine=Advertise, rc=rc)

    call NUOPC_CompSpecialize(gcomp, specLabel="label_RealizeExternal", &
      specRoutine=Realize, rc=rc)

    call NUOPC_CompSpecialize(gcomp, specLabel="label_DataInitialize", &
      specRoutine=DataInitialize, rc=rc)

    call NUOPC_CompSpecialize(gcomp, specLabel="label_Advance", &
      specRoutine=ModelAdvance, rc=rc)

    call NUOPC_CompSpecialize(gcomp, specLabel="label_Finalize", &
      specRoutine=Finalize, rc=rc)

  end subroutine SetServices

  subroutine InitializeP1(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc

    type(ccpp_internal_state_type), pointer :: state
    integer(c_int) :: ccpp_rc
    integer :: counts(2)

    rc = ESMF_SUCCESS

    allocate(state)

    state%ncol = 100_c_int
    state%nlev = 50_c_int

    counts = (/ int(state%ncol), int(state%nlev) /)
    state%grid = ESMF_GridCreate(maxIndex=counts, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="ESMF_GridCreate failed")) then
       deallocate(state)
       return
    end if

    call ESMF_GridCompSetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="ESMF_GridCompSetInternalState failed")) then
       call ESMF_GridDestroy(state%grid, rc=rc)
       deallocate(state)
       return
    end if

    ! Initialize CCPP framework
    call ccpp_init(state%ccpp_state, "my_physics_suite", ccpp_rc)
    if (ccpp_rc /= 0_c_int) then
      rc = ESMF_FAILURE
      if (ESMF_LogFoundError(rcToCheck=rc, msg="ccpp_init failed")) return
    end if

  end subroutine InitializeP1

  subroutine Advertise(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc
    rc = ESMF_SUCCESS

    call NUOPC_Advertise(gcomp, StandardName="air_temperature", StateKind=ESMF_STATEKIND_IMPORT, rc=rc)
    call NUOPC_Advertise(gcomp, StandardName="air_pressure", StateKind=ESMF_STATEKIND_IMPORT, rc=rc)
    call NUOPC_Advertise(gcomp, StandardName="specific_humidity", StateKind=ESMF_STATEKIND_EXPORT, rc=rc)
    call NUOPC_Advertise(gcomp, StandardName="precipitation_rate", StateKind=ESMF_STATEKIND_EXPORT, rc=rc)
  end subroutine Advertise

  subroutine Realize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc

    type(ccpp_internal_state_type), pointer :: state
    type(ESMF_Field) :: field

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="air_temperature", rc=rc)
    call NUOPC_Realize(gcomp, "air_temperature", field=field, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="air_pressure", rc=rc)
    call NUOPC_Realize(gcomp, "air_pressure", field=field, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="specific_humidity", rc=rc)
    call NUOPC_Realize(gcomp, "specific_humidity", field=field, rc=rc)

    field = ESMF_FieldCreate(state%grid, typekind=ESMF_TYPEKIND_R8, name="precipitation_rate", rc=rc)
    call NUOPC_Realize(gcomp, "precipitation_rate", field=field, rc=rc)
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
    call ESMF_GridCompGet(gcomp, importState=importState, exportState=exportState, clock=clock, rc=rc)

    ! 1. PRE-RUN: Map fields and Register with CCPP
    call ESMF_StateGet(importState, "air_temperature", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="air_temperature missing")) return
    call ESMF_FieldGet(field, farrayPtr=state%temp, rc=rc)
    call ccpp_field_add(state%ccpp_state, "air_temperature", state%temp, ccpp_rc)

    call ESMF_StateGet(importState, "air_pressure", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="air_pressure missing")) return
    call ESMF_FieldGet(field, farrayPtr=state%pres, rc=rc)
    call ccpp_field_add(state%ccpp_state, "air_pressure", state%pres, ccpp_rc)

    call ESMF_StateGet(exportState, "specific_humidity", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="specific_humidity missing")) return
    call ESMF_FieldGet(field, farrayPtr=state%q, rc=rc)
    call ccpp_field_add(state%ccpp_state, "specific_humidity", state%q, ccpp_rc)

    call ESMF_StateGet(exportState, "precipitation_rate", field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg="precipitation_rate missing")) return
    call ESMF_FieldGet(field, farrayPtr=state%rain, rc=rc)
    call ccpp_field_add(state%ccpp_state, "precipitation_rate", state%rain, ccpp_rc)

    ! 2. Execute CCPP Run
    call ccpp_run(state%ccpp_state, "my_physics_suite", ccpp_rc)

    if (ccpp_rc /= 0_c_int) then
      rc = ESMF_FAILURE
      if (ESMF_LogFoundError(rcToCheck=rc, msg="ccpp_run failed")) return
    end if

  end subroutine ModelAdvance

  subroutine Finalize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc
    type(ccpp_internal_state_type), pointer :: state
    integer(c_int) :: ccpp_rc

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)

    call ccpp_finalize(state%ccpp_state, ccpp_rc)
    call ESMF_GridDestroy(state%grid, rc=rc)
    deallocate(state)
  end subroutine Finalize

end module CCPP_NUOPC_Cap
