program test_ccpp_driver
  use ESMF
  use NUOPC
  use CCPP_NUOPC_Cap
  implicit none

  type(ESMF_GridComp) :: gcomp
  type(ESMF_State)    :: importState, exportState
  type(ESMF_Clock)    :: clock
  type(ESMF_Time)     :: start_time, stop_time
  type(ESMF_TimeInterval) :: time_step
  type(ESMF_Config)   :: config
  integer :: rc

  call ESMF_Initialize(vmLocalMode=ESMF_VMLOCALMODE_DEFAULT, rc=rc)

  gcomp = ESMF_GridCompCreate(name="CCPP_Cap", rc=rc)

  ! Create and set configuration
  config = ESMF_ConfigCreate(rc=rc)
  call ESMF_ConfigSetAttribute(config, value=10, label="ncol", rc=rc)
  call ESMF_ConfigSetAttribute(config, value=20, label="nlev", rc=rc)
  call ESMF_ConfigSetAttribute(config, value=10, label="ncol_all", rc=rc)
  call ESMF_GridCompSet(gcomp, config=config, rc=rc)

  ! Initialize component
  call ESMF_GridCompSetServices(gcomp, SetServices, rc=rc)

  ! Setup clock
  call ESMF_TimeSet(start_time, yy=2024, mm=1, dd=1, rc=rc)
  call ESMF_TimeSet(stop_time, yy=2024, mm=1, dd=1, h=1, rc=rc)
  call ESMF_TimeIntervalSet(time_step, s=1800, rc=rc)
  clock = ESMF_ClockCreate(timeStep=time_step, startTime=start_time, stopTime=stop_time, rc=rc)
  call ESMF_GridCompSet(gcomp, clock=clock, rc=rc)

  ! Advertise and Realize
  call NUOPC_CompSpecialize(gcomp, specLabel=label_Advertise, specRoutine=Advertise, rc=rc)
  call Advertise(gcomp, rc)

  call NUOPC_CompSpecialize(gcomp, specLabel=label_RealizeProvided, specRoutine=Realize, rc=rc)
  call Realize(gcomp, rc)

  ! Run one step
  call NUOPC_CompSpecialize(gcomp, specLabel=label_Advance, specRoutine=ModelAdvance, rc=rc)
  call ModelAdvance(gcomp, rc)

  if (rc == ESMF_SUCCESS) then
     print *, "CCPP Driver unit test PASSED"
  else
     print *, "CCPP Driver unit test FAILED"
  end if

  call ESMF_GridCompDestroy(gcomp, rc=rc)
  call ESMF_Finalize(rc=rc)

end program test_ccpp_driver
