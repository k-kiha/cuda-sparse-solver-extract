module kistimod_kkh_profile
  use iso_c_binding
  implicit none

  interface
    subroutine kisti_hello() bind(C, name="kisti_hello")
    end subroutine

    ! ===== New: Workspace management (C ABI) =====
    subroutine kisti_solver_workspace_allocate_fortran(n, m) bind(C, name="kisti_solver_workspace_allocate_fortran")
      import :: c_int
      integer(c_int), value :: n, m
    end subroutine

    subroutine kisti_solver_workspace_deallocate_fortran() bind(C, name="kisti_solver_workspace_deallocate_fortran")
    end subroutine

    ! ===== Deprecated: GPU init/solve/finish (C ABI) =====
    subroutine kisti_gpu_init(n, m) bind(C, name="kisti_gpu_init")
      import :: c_int
      integer(c_int), value :: n, m
    end subroutine

    subroutine kisti_gpu_solver(n, m, Arowp, Acoli, Aval, b) bind(C, name="kisti_gpu_solver")
      import :: c_int, c_double
      integer(c_int), value :: n, m
      integer(c_int) :: Arowp(*), Acoli(*)
      real(c_double) :: Aval(*), b(*)
    end subroutine

    subroutine kisti_gpu_finish() bind(C, name="kisti_gpu_finish")
    end subroutine

  end interface

contains
  subroutine kistimod_hello()
    write(*,*) "Hello from kistimod_kkh_profile!"
    call kisti_hello()
  end subroutine

  ! ===== New: Workspace management wrappers =====
  subroutine kistimod_solver_workspace_allocate(n, m)
    integer, intent(in) :: n, m
    call kisti_solver_workspace_allocate_fortran(int(n,c_int), int(m,c_int))
  end subroutine

  subroutine kistimod_solver_workspace_deallocate()
    call kisti_solver_workspace_deallocate_fortran()
  end subroutine

  ! ===== Deprecated: Old wrappers (kept for backward compatibility) =====
  subroutine kistimod_gpu_init(n, m)
    integer, intent(in) :: n, m
    call kisti_gpu_init(int(n,c_int), int(m,c_int))
  end subroutine

  subroutine kistimod_gpu_solver(n, m, Arowp, Acoli, Aval, b)
    integer, intent(in) :: n, m
    ! 아래 4개 타입은 "A 쪽"과 맞춰야 합니다.
    ! Arowp/Acoli는 원래 integer 배열이어야 정상입니다.
    integer, intent(in) :: Arowp(n+1), Acoli(m)
    real*8,  intent(in) :: Aval(m)
    real*8,  intent(inout) :: b(n)

    call kisti_gpu_solver(int(n,c_int), int(m,c_int), Arowp, Acoli, Aval, b)
  end subroutine

  subroutine kistimod_gpu_finish()
    call kisti_gpu_finish()
  end subroutine
end module
