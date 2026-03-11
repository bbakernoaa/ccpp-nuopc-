module CCPP_NUOPC_Cap
  use ESMF
  use NUOPC
  use NUOPC_Model, modelSS => SetServices
  use, intrinsic :: iso_c_binding
  use ccpp_internal_state_mod
  use ccpp_inline_cdeps_mod
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
    type(ESMF_Config) :: config

    rc = ESMF_SUCCESS

    ! Allocate and set internal state
    allocate(state)

    ! Retrieve dimensions from ESMF gridded component configuration
    call ESMF_GridCompGet(gcomp, config=config, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) then
      deallocate(state)
      return
    end if

    call ESMF_ConfigGetAttribute(config, value=state%ncol, label="ncol", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) then
      deallocate(state)
      return
    end if

    call ESMF_ConfigGetAttribute(config, value=state%nlev, label="nlev", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) then
      deallocate(state)
      return
    end if

    call ESMF_ConfigGetAttribute(config, value=state%ncol_all, label="ncol_all", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) then
      deallocate(state)
      return
    end if

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
    type(ESMF_Clock) :: clock
    type(ESMF_Field) :: field
    type(ESMF_VM)    :: vm
    integer :: counts(2)
    integer(kind_int) :: ccpp_rc
    integer :: mytask

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Create grid
    counts = (/ int(state%ncol), int(state%nlev) /)
    state%grid = ESMF_GridCreate(maxIndex=counts, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Create mesh for CDEPS integration
    state%mesh = ESMF_MeshCreate(parametricDim=1, spatialDim=1, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

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

    ! Initialize CCPP physics
    call ccpp_physics_init(state%ccpp_state, suite_name="my_physics_suite", ierr=ccpp_rc)
    if (ccpp_rc /= 0_kind_int) then
      rc = ESMF_FAILURE
      return
    end if

    ! Get clock and VM from component
    call ESMF_GridCompGet(gcomp, clock=clock, vm=vm, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Get PET (task ID)
    call ESMF_VMGet(vm, localPet=mytask, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Initialize inline CDEPS
    call ccpp_inline_init(gcomp, clock, state%mesh, mytask, rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

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
    integer(kind_int) :: ccpp_rc
    integer :: thrd_no

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return
    call ESMF_GridCompGet(gcomp, importState=importState, exportState=exportState, clock=clock, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Map ESMF field pointers to internal state for CCPP access
    call ESMF_StateGet(importState, "air_temperature", field, rc=rc)
    call ESMF_FieldGet(field, farrayPtr=state%temp, rc=rc)
    call ESMF_StateGet(importState, "air_pressure", field, rc=rc)
    call ESMF_FieldGet(field, farrayPtr=state%pres, rc=rc)
    call ESMF_StateGet(exportState, "specific_humidity", field, rc=rc)
    call ESMF_FieldGet(field, farrayPtr=state%q, rc=rc)
    call ESMF_StateGet(exportState, "precipitation_rate", field, rc=rc)
    call ESMF_FieldGet(field, farrayPtr=state%rain, rc=rc)

!> \section arg_table_CCPP_NUOPC_Cap Argument Table
!! \htmlinclude CCPP_NUOPC_Cap.html
!!

    ! Execute CCPP Run phases
    call ccpp_physics_timestep_init(state%ccpp_state, suite_name="my_physics_suite", ierr=ccpp_rc)
    if (ccpp_rc == 0_kind_int) then
      ! For now, call physics serially to ensure correctness and avoid race conditions
      call ccpp_physics_run(state%ccpp_state, suite_name="my_physics_suite", ierr=ccpp_rc)
    end if
    if (ccpp_rc == 0_kind_int) then
      call ccpp_physics_timestep_finalize(state%ccpp_state, suite_name="my_physics_suite", ierr=ccpp_rc)
    end if

    if (ccpp_rc /= 0_kind_int) then
      rc = ESMF_FAILURE
      return
    end if

    ! Run inline CDEPS
    call ccpp_inline_run(clock, rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

  end subroutine ModelAdvance

  subroutine Finalize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc
    type(ccpp_internal_state_type), pointer :: state
    integer(kind_int) :: ccpp_rc

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call ccpp_physics_finalize(state%ccpp_state, suite_name="my_physics_suite", ierr=ccpp_rc)
    call ccpp_finalize(state%ccpp_state, ccpp_rc)
    call ESMF_GridDestroy(state%grid, rc=rc)
    call ESMF_MeshDestroy(state%mesh, rc=rc)
    deallocate(state)
  end subroutine Finalize

end module CCPP_NUOPC_Cap
