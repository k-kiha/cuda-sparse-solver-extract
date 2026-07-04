program main
  use kistimod_kkh_profile
  implicit none
  integer :: n,m
  integer, allocatable :: Arowp(:),Acoli(:)
  real*8, allocatable :: Aval(:), b(:), x(:)

  integer :: unit,i,istep,nstep

  !********** 초기화 부분 *********
  open(newunit=unit, file='./Mtest/spmv_nm.txt', status='old', action='read')
  read(unit, *) N
  read(unit, *) M
  close(unit)
  allocate( Arowp(n+1), Acoli(m), Aval(m), b(n) )
  call init_sparsematrix(N, M, Arowp, Acoli, Aval, b, x)
  !*****************************

  call kistimod_hello()

  ! New pattern: Allocate workspace once
  call kistimod_solver_workspace_allocate(n,m)

  ! Example: solve multiple times (e.g., time-stepping loop)
  nstep = 3
  write(*,*) "Running solver for", nstep, "steps..."
  do istep=1,nstep
    write(*,*) "  Step", istep, "/", nstep
    call kistimod_gpu_solver(n,m, Arowp,Acoli,Aval, b)
  enddo

  ! Deallocate workspace once
  call kistimod_solver_workspace_deallocate()

  deallocate( Arowp, Acoli, Aval, b )

  write(*,*) "Program completed successfully."

end program


subroutine init_sparsematrix(N, M, Arowp, Acoli, Aval, b, x)
  implicit none
  integer, intent(in) :: N, M
  integer :: Arowp(N+1), Acoli(M)
  real*8 :: Aval(M), b(N), x(N)

  integer :: idex_row, idex_element, i, j
  real*8  :: value

  integer :: ios
  character(len=100) :: filename
  integer :: unit

  filename = './Mtest/spmv_Arowp.txt'
  open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
  if (ios /= 0) stop 'Error opening spmv_Arowp.txt'
  read(unit, *, iostat=ios) Arowp  ! 한 번에 전체 배열로 읽기
  close(unit)
  

  filename = './Mtest/spmv_Acoli.txt'
  open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
  if (ios /= 0) stop 'Error opening spmv_Acoli.txt'
  read(unit, *, iostat=ios) Acoli  ! 한 번에 전체 배열로 읽기
  close(unit)


  filename = './Mtest/spmv_Aval.txt'
  open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
  if (ios /= 0) stop 'Error opening spmv_Aval.txt'
  read(unit, *, iostat=ios) Aval! 한 번에 전체 배열로 읽기
  close(unit)

  filename = './Mtest/spmv_x.txt'
  open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
  if (ios /= 0) stop 'Error opening spmv_x.txt'
  read(unit, *, iostat=ios) x  ! 한 번에 전체 배열로 읽기
  close(unit)

  filename = './Mtest/spmv_b.txt'
  open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
  if (ios /= 0) stop 'Error opening spmv_b.txt'
  read(unit, *, iostat=ios) b  ! 한 번에 전체 배열로 읽기
  close(unit)

end subroutine init_sparsematrix
