module CCPP_NUOPC_Cap
  use ESMF
  use NUOPC
  use NUOPC_Model, modelSS => SetServices
  use, intrinsic :: iso_c_binding
  use ccpp_internal_state_mod
  use ccpp_inline_cdeps_mod
  use ccpp_driver_mod
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
    type(ESMF_Field) :: field
    type(ESMF_Clock) :: clock
    type(ESMF_VM)    :: vm
    integer :: mytask
    integer :: counts(2)

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

    ! Initialize CCPP via unified driver
    call ccpp_driver_init(gcomp, suite_name="my_physics_suite", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Create mesh for CDEPS integration
    state%mesh = ESMF_MeshCreate(parametricDim=1, spatialDim=1, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

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

    type(ESMF_State) :: importState, exportState
    type(ESMF_Clock) :: clock

    rc = ESMF_SUCCESS
    call ESMF_GridCompGet(gcomp, importState=importState, exportState=exportState, clock=clock, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

!> \section arg_table_CCPP_NUOPC_Cap Argument Table
!! \htmlinclude CCPP_NUOPC_Cap.html
!!

    ! Execute CCPP via unified driver
    call ccpp_driver_run(gcomp, importState, exportState, suite_name="my_physics_suite", group_name="physics", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    ! Run inline CDEPS
    call ccpp_inline_run(clock, rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

  end subroutine ModelAdvance

  subroutine Finalize(gcomp, rc)
    type(ESMF_GridComp)  :: gcomp
    integer, intent(out) :: rc
    type(ccpp_internal_state_type), pointer :: state

    rc = ESMF_SUCCESS
    call ESMF_GridCompGetInternalState(gcomp, state, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=__FILE__)) return

    call ccpp_driver_finalize(gcomp, suite_name="my_physics_suite", rc=rc)
    call ESMF_GridDestroy(state%grid, rc=rc)
    call ESMF_MeshDestroy(state%mesh, rc=rc)
    deallocate(state)
  end subroutine Finalize

end module CCPP_NUOPC_Cap
