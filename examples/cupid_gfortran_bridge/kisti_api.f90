module kisti_api
  use iso_c_binding
  use mod_kisti
  implicit none

  interface
    ! C function declarations for workspace management
    subroutine c_kisti_solver_workspace_allocate(n, m) bind(C, name="kisti_solver_workspace_allocate")
      import :: c_int
      integer(c_int), value :: n, m
    end subroutine

    subroutine c_kisti_solver_workspace_deallocate() bind(C, name="kisti_solver_workspace_deallocate")
    end subroutine
  end interface

contains

  subroutine kisti_hello() bind(C, name="kisti_hello")
    ! 여기서는 nvfortran 영역이라 mod_kisti를 마음대로 쓸 수 있습니다.
    call mod_kisti_hello()
  end subroutine

  ! ===== 추가: workspace allocate =====
  subroutine kisti_solver_workspace_allocate(n, m) bind(C, name="kisti_solver_workspace_allocate_fortran")
    integer(c_int), value :: n, m
    ! Allocate GPU memory for matrix/vector storage (existing)
    call mod_kisti_gpumalloc_c(n, m)
    ! Allocate solver workspace
    call c_kisti_solver_workspace_allocate(n, m)
  end subroutine

  ! ===== 추가: workspace deallocate =====
  subroutine kisti_solver_workspace_deallocate() bind(C, name="kisti_solver_workspace_deallocate_fortran")
    ! Deallocate solver workspace
    call c_kisti_solver_workspace_deallocate()
    ! Deallocate GPU memory for matrix/vector storage (existing)
    call mod_kisti_gpumalloc_delete_c()
  end subroutine

  ! ===== 추가: init (deprecated, now use workspace_allocate) =====
  subroutine kisti_gpu_init(n, m) bind(C, name="kisti_gpu_init")
    integer(c_int), value :: n, m
    call kisti_solver_workspace_allocate(n, m)
  end subroutine

  ! ===== 추가: solver =====
  subroutine kisti_gpu_solver(n, m, Arowp, Acoli, Aval, b) bind(C, name="kisti_gpu_solver")
    integer(c_int), value :: n, m
    integer(c_int), intent(in) :: Arowp(*), Acoli(*)
    real(c_double), intent(in) :: Aval(*)
    real(c_double), intent(inout) :: b(*)

    call mod_kisti_switch2(n, m, Arowp, Acoli, Aval, b)
  end subroutine

  ! ===== 추가: finish (deprecated, now use workspace_deallocate) =====
  subroutine kisti_gpu_finish() bind(C, name="kisti_gpu_finish")
    call kisti_solver_workspace_deallocate()
  end subroutine

end module kisti_api
