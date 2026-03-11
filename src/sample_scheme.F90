module sample_scheme
  use, intrinsic :: iso_c_binding
  implicit none
  private
  public :: sample_scheme_init
  public :: sample_scheme_run
  public :: sample_scheme_finalize

contains

  subroutine sample_scheme_init(errmsg, errflg)
    character(len=*), intent(out) :: errmsg
    integer,          intent(out) :: errflg
    errmsg = ''
    errflg = 0
  end subroutine sample_scheme_init

  subroutine sample_scheme_run(ncol, nlev, temp, pres, q, rain, errmsg, errflg)
!> \section arg_table_sample_scheme_run Argument Table
!! \htmlinclude sample_scheme_run.html
!!
    integer,          intent(in)    :: ncol, nlev
    real(c_double),   intent(inout) :: temp(ncol, nlev)
    real(c_double),   intent(in)    :: pres(ncol, nlev)
    real(c_double),   intent(inout) :: q(ncol, nlev)
    real(c_double),   intent(out)   :: rain(ncol, nlev)
    character(len=*), intent(out)   :: errmsg
    integer,          intent(out)   :: errflg

    integer :: i, k

    errmsg = ''
    errflg = 0

    do k = 1, nlev
       do i = 1, ncol
          ! Simple dummy physics: increase temperature slightly
          temp(i,k) = temp(i,k) + 0.01_c_double
          ! Simple condensation: q decreases, rain increases
          rain(i,k) = q(i,k) * 0.1_c_double
          q(i,k) = q(i,k) * 0.9_c_double
       end do
    end do

  end subroutine sample_scheme_run

  subroutine sample_scheme_finalize(errmsg, errflg)
    character(len=*), intent(out) :: errmsg
    integer,          intent(out) :: errflg
    errmsg = ''
    errflg = 0
  end subroutine sample_scheme_finalize

end module sample_scheme
