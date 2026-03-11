!> This module contains a set of subroutines that enables inline CDEPS capability
module ccpp_inline_cdeps_mod
  use NUOPC , only: NUOPC_CompAttributeGet
  use ESMF , only: ESMF_GridComp, ESMF_Grid, ESMF_Mesh
  use ESMF , only: ESMF_Clock, ESMF_Time, ESMF_TimeGet, ESMF_ClockGet
  use ESMF , only: ESMF_KIND_R8, ESMF_SUCCESS, ESMF_FAILURE, ESMF_LogFoundError
  use ESMF , only: ESMF_LOGERR_PASSTHRU, ESMF_LOGMSG_INFO, ESMF_LOGWRITE
  use ESMF , only: ESMF_END_ABORT, ESMF_Finalize, ESMF_MAXSTR

  ! Actual CDEPS/dshr modules
  use dshr_mod , only: dshr_pio_init
  use dshr_strdata_mod , only: shr_strdata_type, shr_strdata_print
  use dshr_strdata_mod , only: shr_strdata_init_from_inline
  use dshr_strdata_mod , only: shr_strdata_advance
  use dshr_methods_mod , only: dshr_fldbun_getfldptr, dshr_fldbun_Field_diagnose
  use dshr_stream_mod , only: shr_stream_init_from_esmfconfig

  implicit none
  private

  public ccpp_inline_init
  public ccpp_inline_run

  type(shr_strdata_type), allocatable, target :: sdat(:)
  integer :: logunit
  character(len=ESMF_MAXSTR) :: stream_name

contains

  subroutine ccpp_inline_init(gcomp, model_clock, model_mesh, mytask, rc)
    type(ESMF_GridComp) , intent(in) :: gcomp
    type(ESMF_Clock)    , intent(in) :: model_clock
    type(ESMF_Mesh)     , intent(in) :: model_mesh
    integer             , intent(in) :: mytask
    integer             , intent(out) :: rc

    ! local variables
    logical :: isPresent, isSet
    integer :: ns, l
    integer :: nstreams
    type(shr_strdata_type) :: sdatconfig
    character(len=ESMF_MAXSTR) :: value, streamfilename
    character(len=ESMF_MAXSTR), allocatable :: filelist(:)
    character(len=ESMF_MAXSTR), allocatable :: filevars(:,:)

    rc = ESMF_SUCCESS

    call NUOPC_CompAttributeGet(gcomp, name="streamfilename", value=value, &
      isPresent=isPresent, isSet=isSet, rc=rc)
    if (rc /= ESMF_SUCCESS) return

    if (isPresent .and. isSet) then
      streamfilename = value
    else
      call ESMF_LogWrite('streamfilename must be provided', ESMF_LOGMSG_INFO)
      rc = ESMF_FAILURE
      return
    endif

    if (mytask == 0) then
      open (newunit=logunit, file='log.ccpp.cdeps')
    else
      logunit = 6
    endif

    ! CDEPS Init PIO
    call dshr_pio_init(gcomp, sdatconfig, logunit, rc=rc)
    if (rc /= ESMF_SUCCESS) return

    ! Read available stream definitions
    call shr_stream_init_from_esmfconfig(trim(streamfilename), &
      sdatconfig%stream, logunit, &
      sdatconfig%pio_subsystem, sdatconfig%io_type, sdatconfig%io_format, rc=rc)
    if (rc /= ESMF_SUCCESS) return

    nstreams = size(sdatconfig%stream)
    if (.not. allocated(sdat)) allocate(sdat(nstreams))

    ! Loop over streams and initialize from inline
    do ns = 1, nstreams
      sdat(ns)%pio_subsystem => sdatconfig%pio_subsystem
      sdat(ns)%io_type = sdatconfig%io_type
      sdat(ns)%io_format = sdatconfig%io_format

      allocate(filelist(sdatconfig%stream(ns)%nfiles))
      allocate(filevars(sdatconfig%stream(ns)%nvars,2))

      do l = 1, sdatconfig%stream(ns)%nfiles
        filelist(l) = trim(sdatconfig%stream(ns)%file(l)%name)
      enddo
      do l = 1, sdatconfig%stream(ns)%nvars
        filevars(l,1) = trim(sdatconfig%stream(ns)%varlist(l)%nameinfile)
        filevars(l,2) = trim(sdatconfig%stream(ns)%varlist(l)%nameinmodel)
      enddo

      write(stream_name,fmt='(a,i2.2)') 'stream_', ns
      call shr_strdata_init_from_inline(sdat(ns), &
        my_task = mytask, &
        logunit = logunit, &
        compname = 'CCPP', &
        model_clock = model_clock, &
        model_mesh = model_mesh, &
        stream_name = trim(stream_name), &
        stream_meshfile = trim(sdatconfig%stream(ns)%meshfile), &
        stream_filenames = filelist, &
        stream_yearFirst = sdatconfig%stream(ns)%yearFirst, &
        stream_yearLast = sdatconfig%stream(ns)%yearLast, &
        stream_yearAlign = sdatconfig%stream(ns)%yearAlign, &
        stream_fldlistFile = filevars(:,1), &
        stream_fldListModel = filevars(:,2), &
        stream_lev_dimname = trim(sdatconfig%stream(ns)%lev_dimname), &
        stream_mapalgo = trim(sdatconfig%stream(ns)%mapalgo), &
        stream_offset = sdatconfig%stream(ns)%offset, &
        stream_taxmode = trim(sdatconfig%stream(ns)%taxmode), &
        stream_dtlimit = sdatconfig%stream(ns)%dtlimit, &
        stream_tintalgo = trim(sdatconfig%stream(ns)%tInterpAlgo), &
        stream_src_mask = sdatconfig%stream(ns)%src_mask_val, &
        stream_dst_mask = sdatconfig%stream(ns)%dst_mask_val, &
        rc = rc)
      if (rc /= ESMF_SUCCESS) return

      deallocate(filelist)
      deallocate(filevars)
    enddo

  end subroutine ccpp_inline_init

  subroutine ccpp_inline_run(clock, rc)
    type(ESMF_Clock) , intent(in) :: clock
    integer          , intent(out) :: rc
    type(ESMF_Time)  :: date
    integer          :: year, mon, day, sec, mcdate
    integer          :: nstreams, ns

    rc = ESMF_SUCCESS

    if (.not. allocated(sdat)) return

    ! Current model date
    call ESMF_ClockGet( clock, currTime=date, rc=rc )
    if (rc /= ESMF_SUCCESS) return
    call ESMF_TimeGet(date, yy=year, mm=mon, dd=day, s=sec, rc=rc)
    if (rc /= ESMF_SUCCESS) return
    mcdate = year*10000 + mon*100 + day

    nstreams = size(sdat)
    do ns = 1, nstreams
      write(stream_name,fmt='(a,i2.2)') 'stream_', ns
      call shr_strdata_advance(sdat(ns), ymd=mcdate, tod=sec, &
        logunit=logunit, istr=trim(stream_name), rc=rc)
      if (rc /= ESMF_SUCCESS) return
    enddo

  end subroutine ccpp_inline_run

end module ccpp_inline_cdeps_mod
