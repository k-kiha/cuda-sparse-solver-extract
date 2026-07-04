
module mod_kisti
    ! Fortran example adapter for the CUDA sparse solver core.
    ! NVFORTRAN cudafor device arrays hold CSR data on the GPU, and bind(C)
    ! forwards those device pointers to the public kisti_solver_c ABI.
    use iso_c_binding
    use cudafor
    implicit none
    
    private 
    real*8, parameter :: eps = 1.0d-10

    public :: mod_kisti_hello
    public :: mod_kisti_switch
    public :: mod_kisti_malloc
    public :: mod_kisti_malloc_delete
    public :: mod_kisti_matrix_init
    public :: mod_kisti_gpumalloc_c
    public :: mod_kisti_gpumalloc_delete_c
  
    type, public :: mod_kisti_sparse_matrix_csr
        integer, allocatable :: rowp(:), coli(:)
        real*8 , allocatable :: v(:)
    end type mod_kisti_sparse_matrix_csr

    integer(c_int), public, device, allocatable :: GPUrowp(:), GPUcoli(:)
    real(c_double), public, device, allocatable :: GPUv(:), GPUb(:)

    interface
        ! [Fortran-CUDA ABI] C entrypoint; c_A_* and c_b are device pointers.
        subroutine kisti_solver_c(n,m, c_A_rowp, c_A_coli, c_A_v, c_b) bind(c)
            use iso_c_binding
            implicit none
            integer(c_int), value :: n,m
            integer(c_int), device :: c_A_rowp(*), c_A_coli(*)
            real(c_double), device :: c_A_v(*), c_b(*)
        end subroutine kisti_solver_c
    end interface

contains

    subroutine mod_kisti_hello()
        implicit none
        write(*,*) "Hello from mod_kisti!"
    end subroutine mod_kisti_hello

    subroutine mod_kisti_switch(N, M, A, b)
        implicit none
        integer, intent(in) :: N,M
        type(mod_kisti_sparse_matrix_csr) :: A
        real*8 :: b(N)
        real*8 :: temp(N)

        real*8 :: ta0, ta1
        real*8 :: tb0, tb1
        real*8 :: tc0, tc1

        integer :: i

        !=====CPU=====
        ! call kisti_solver_bicg(N, M, A    , b    )
        ! call kisti_solver_bicg_pr_diag(N, M, A    , b    )
        ! call kisti_solver_cg(N, M, A    , b    )
        ! call kisti_solver_cg_pr_diag(N, M, A    , b    )

        !=====GPU=====
        call cpu_time(ta0)
        ! [NVFORTRAN device] Host CSR/vector data are copied into device arrays.
        GPUrowp(1:N+1) = A%rowp(1:N+1)
        GPUcoli(1:M  ) = A%coli(1:M  ) 
        GPUv   (1:M  ) = A%v   (1:M  )
        GPUb   (1:N  ) = b     (1:N  )
        call cpu_time(ta1)
        
        call cpu_time(tb0)
        ! [Fortran-CUDA ABI] Same kisti_solver_c device-pointer ABI used by C.
        call kisti_solver_c(N,M, GPUrowp,GPUcoli,GPUv,GPUb)
        call cpu_time(tb1)

        call cpu_time(tc0)
        A%rowp(1:N+1) = GPUrowp(1:N+1)
        A%coli(1:M  ) = GPUcoli(1:M  )
        A%v   (1:M  ) = GPUv   (1:M  )
        b     (1:N  ) = GPUb   (1:N  )
        call cpu_time(tc1)

        write(*,*) "H2D  :",ta1-ta0
        write(*,*) "Compu:",tb1-tb0
        write(*,*) "D2H  :",tc1-tc0

    end subroutine mod_kisti_switch
    !-     -     -     -     -     -     -     -     -     -     -     -     -
    !-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
    !-------------------------------------------------------------------------
    !-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
    !-     -     -     -     -     -     -     -     -     -     -     -     -

        subroutine mod_kisti_malloc(N, M, A)
            implicit none
            integer :: N, M
            type(mod_kisti_sparse_matrix_csr):: A

            allocate(A%rowp(N+1))
            allocate(A%coli(M  )) 
            allocate(A%v   (M  ))

        end subroutine mod_kisti_malloc

        subroutine mod_kisti_gpumalloc_c(N, M)
            implicit none
            integer :: N, M, ierr

            allocate(GPUrowp(N+1))
            allocate(GPUcoli(M  )) 
            allocate(GPUv   (M  ))
            allocate(GPUb   (N  ))
        end subroutine mod_kisti_gpumalloc_c

        subroutine mod_kisti_malloc_delete(A)
            implicit none
            type(mod_kisti_sparse_matrix_csr):: A

            deallocate(A%rowp )
            deallocate(A%coli ) 
            deallocate(A%v    )

        end subroutine mod_kisti_malloc_delete

        subroutine mod_kisti_gpumalloc_delete_c()
            implicit none

            deallocate(GPUrowp)
            deallocate(GPUcoli) 
            deallocate(GPUv   )
            deallocate(GPUb   )

        end subroutine mod_kisti_gpumalloc_delete_c
        
        subroutine mod_kisti_matrix_init(N, M, A, b, x)
            implicit none
            integer, intent(in) :: N, M
            type(mod_kisti_sparse_matrix_csr) :: A
            real*8                            :: b(N), x(N)

            integer :: idex_row, idex_element, i, j
            real*8  :: value

            integer :: ios
            character(len=100) :: filename
            integer :: unit
        
            filename = './Mtest/spmv_Arowp.txt'
            open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
            if (ios /= 0) stop 'Error opening spmv_Arowp.txt'
            read(unit, *, iostat=ios) A%rowp  ! 한 번에 전체 배열로 읽기
            close(unit)
            

            filename = './Mtest/spmv_Acoli.txt'
            open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
            if (ios /= 0) stop 'Error opening spmv_Acoli.txt'
            read(unit, *, iostat=ios) A%coli  ! 한 번에 전체 배열로 읽기
            close(unit)


            filename = './Mtest/spmv_Aval.txt'
            open(newunit=unit, file=filename, status='old', action='read', iostat=ios)
            if (ios /= 0) stop 'Error opening spmv_Aval.txt'
            read(unit, *, iostat=ios) A%v  ! 한 번에 전체 배열로 읽기
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

            ! open(unit=111, file='./Mtest/matrix_output.csv', status='replace', action='write')
            ! write(111,*) "i,j,value"
            ! do idex_row = 1, N
            !     i = idex_row
            !     do idex_element = A%rowp(i), A%rowp(i+1)-1
            !         j = A%coli(idex_element)
            !         value = A%v(idex_element)
            !         write(111,'(I15,1A1,I15,1A1,1E30.15)') i,",",j,",",value
            !     end do
            ! end do
            ! close(111)

        end subroutine mod_kisti_matrix_init

        subroutine kisti_solver_bicg(N, M, A, x)
            implicit none
            integer :: N, M
            type(mod_kisti_sparse_matrix_csr) :: A
            real*8 :: x(N)

            real*8 :: value

            real*8, allocatable :: r(:),rhat(:),p(:),h(:),s(:),t(:),v(:),Ax(:)
            real*8 :: alpha, beta, rho_a, rho_b, omega
            real*8 :: rr1,rr2
            integer :: iter

            allocate(r(1:N),rhat(1:N),p(1:N),h(1:N),s(1:N),t(1:N),v(1:N),Ax(1:N))

            call sp_mv(N, M, A%rowp, A%coli, A%v, x, Ax)
            r(1:N) = x(1:N) - Ax(1:N)
            rhat(1:N) = r(1:N)
            rho_a = sum(rhat(1:N)*r(1:N))
            p(1:N) = r(1:N)

            do iter=1,5000
                call sp_mv(N, M, A%rowp, A%coli, A%v, p, v)
                alpha = rho_a / sum(rhat(1:N)*v(1:N))
                x(1:N) = x(1:N) + alpha*p(1:N)
                s(1:N) = r(1:N) - alpha*v(1:N)

                rr1 = sqrt(sum(s(1:N)*s(1:N)))
                if ( rr1 < eps ) then
                    exit
                end if

                call sp_mv(N, M, A%rowp, A%coli, A%v, s, t )

                omega = sum(t(1:N)*s(1:N))/sum(t(1:N)*t(1:N))

                x(1:N) = x(1:N) + omega*s(1:N)
                r(1:N) = s(1:N) - omega*t(1:N)

                rr2 = sqrt(sum(r(1:N)*r(1:N)))
                if ( rr2 < eps ) then
                    exit
                end if

                rho_b = sum(rhat(1:N)*r(1:N))
                beta = (rho_b/rho_a)*(alpha/omega)
                
                p(1:N) = r(1:N) + beta*(p(1:N) - omega*v(1:N))

                rho_a = rho_b

                write(*,*) "bicg_pr",iter, rr1, rr2
            end do

            deallocate(r,rhat,p,h,s,t,v,Ax)
        end subroutine kisti_solver_bicg

        subroutine kisti_solver_bicg_pr_diag(N, M, A, x)
            implicit none
            integer :: N, M
            type(mod_kisti_sparse_matrix_csr) :: A
            real*8 :: x(N)

            real*8 :: value

            real*8, allocatable :: r(:),rhat(:),p(:),h(:),s(:),t(:),v(:),Ax(:)
            real*8, allocatable :: invM(:),y(:),z(:)
            real*8 :: alpha, beta, rho_a, rho_b, omega
            real*8 :: rr1,rr2
            integer :: iter

            allocate(r(1:N),rhat(1:N),p(1:N),h(1:N),s(1:N),t(1:N),v(1:N),Ax(1:N))
            allocate(invM(1:N),y(1:N),z(1:N))

            call diag(N, M, A%rowp, A%coli, A%v, invM)

            call sp_mv(N, M, A%rowp, A%coli, A%v, x, Ax)

            r(1:N)    = x(1:N) - Ax(1:N)
            rhat(1:N) = r(1:N)
            rho_a     = sum(rhat(1:N)*r(1:N))
            p(1:N)    = r(1:N)

            do iter=1,5000
                y(1:N) = invM(1:N)*p(1:N)
                call sp_mv(N, M, A%rowp, A%coli, A%v, y, v)
                alpha = rho_a / sum(rhat(1:N)*v(1:N))
                x(1:N) = x(1:N) + alpha*y(1:N)
                s(1:N) = r(1:N) - alpha*v(1:N)

                rr1 = sqrt(sum(s(1:N)*s(1:N)))
                if ( rr1 < eps ) then
                    exit
                end if

                z(1:N) = invM(1:N)*s(1:N)
                call sp_mv(N, M, A%rowp, A%coli, A%v, z, t )

                omega  = sum(invM(1:N)*t(1:N)*z(1:N))/sum(invM(1:N)*t(1:N)*invM(1:N)*t(1:N))

                x(1:N) = x(1:N) + omega*z(1:N)
                r(1:N) = s(1:N) - omega*t(1:N)

                rr2 = sqrt(sum(r(1:N)*r(1:N)))
                if ( rr2 < eps ) then
                    exit
                end if

                rho_b = sum(rhat(1:N)*r(1:N))
                beta  = (rho_b/rho_a)*(alpha/omega)
                
                p(1:N)= r(1:N) + beta*(p(1:N) - omega*v(1:N))

                rho_a = rho_b

                write(*,*) "bicg_pr_diag",iter, rr1, rr2
            end do
            
            deallocate(invM,y,z)
            deallocate(r,rhat,p,h,s,t,v,Ax)
        end subroutine kisti_solver_bicg_pr_diag

        subroutine kisti_solver_cg(N, M, A, x)
            implicit none
            integer :: N, M
            type(mod_kisti_sparse_matrix_csr) :: A
            real*8 :: x(N)

            real*8 :: value

            real*8, allocatable :: r(:),p(:),Ax(:)
            real*8 :: alpha, beta, rho_a, rho_b
            integer :: iter

            allocate(r(1:N),p(1:N),Ax(1:N))

            call sp_mv(N, M, A%rowp, A%coli, A%v, x, Ax)
            r(1:N) = x(1:N) - Ax(1:N)
            p(1:N) = r(1:N)

            rho_a = sum(r(1:N)*r(1:N))

            do iter=1,5000
                call sp_mv(N, M, A%rowp, A%coli, A%v, p, Ax)
                alpha = rho_a / sum(p(1:N)*Ax(1:N))
                x(1:N) = x(1:N) + alpha* p(1:N)
                r(1:N) = r(1:N) - alpha*Ax(1:N)

                rho_b = sum(r(1:N)*r(1:N))
                if ( sqrt(rho_b) < eps ) then
                    exit
                end if

                beta = rho_b/rho_a
                
                p(1:N) = r(1:N) + beta*p(1:N)

                rho_a = rho_b

                write(*,*) "kisti_solver_cg",iter, sqrt(rho_b)
            end do

            deallocate(r,p,Ax)
        end subroutine kisti_solver_cg

        subroutine kisti_solver_cg_pr_diag(N, M, A, x)
            implicit none
            integer :: N, M
            type(mod_kisti_sparse_matrix_csr) :: A
            real*8 :: x(N)

            real*8 :: value

            real*8, allocatable :: r(:),z(:),p(:),Ax(:)
            real*8, allocatable :: invM(:)
            real*8 :: alpha, beta, rho_a, rho_b
            integer :: iter

            allocate(r(1:N),z(1:N),p(1:N),Ax(1:N), invM(1:N))

            call diag(N, M, A%rowp, A%coli, A%v, invM)

            call sp_mv(N, M, A%rowp, A%coli, A%v, x, Ax)
            r(1:N) = x(1:N) - Ax(1:N)
            z(1:N) = invM(1:N)*r(1:N)
            p(1:N) = z(1:N)

            rho_a = sum(r(1:N)*z(1:N))

            do iter=1,5000
                call sp_mv(N, M, A%rowp, A%coli, A%v, p, Ax)
                alpha = rho_a / sum(p(1:N)*Ax(1:N))
                x(1:N) = x(1:N) + alpha* p(1:N)
                r(1:N) = r(1:N) - alpha*Ax(1:N)

                z(1:N) = invM(1:N)*r(1:N)
                rho_b = sum(r(1:N)*z(1:N))
                if ( sqrt(sum(r(1:N)*r(1:N))) < eps ) then
                    exit
                end if

                beta = rho_b/rho_a
                
                p(1:N) = z(1:N) + beta*p(1:N)

                rho_a = rho_b

                write(*,*) "kisti_solver_cg_pr_diag",iter, sqrt(sum(r(1:N)*r(1:N)))
            end do

            deallocate(r,z,p,Ax,invM)
        end subroutine kisti_solver_cg_pr_diag

        subroutine sp_mv(N, M, A_rowp, A_coli, A_v, b, sum)
            implicit none
            integer, intent(in) :: N, M
            integer, intent(in) :: A_rowp(0:N), A_coli(0:M-1)
            real*8, intent(in) :: A_v(0:M-1)
            real*8, intent(in) :: b(0:N-1)
            real*8, intent(inout) :: sum(0:N-1)

            integer :: idex_element,idex_row, i, j

            sum(0:N-1)=0.d0
            
            do idex_row = 0, N-1
                i = idex_row
                do idex_element = A_rowp(i), A_rowp(i+1)-1
                    j = A_coli(idex_element)
                    sum(i) = sum(i) + A_v(idex_element)*b(j)
                    ! write(*,'(4I8)') i, j,i+1, j+1
                end do
            end do

        end subroutine sp_mv

        subroutine diag(N, M, A_rowp, A_coli, A_v, invM)
            implicit none
            integer, intent(in) :: N, M
            integer, intent(in) :: A_rowp(0:N), A_coli(0:M-1)
            real*8, intent(in) :: A_v(0:M-1)
            real*8, intent(inout) :: invM(0:N-1)

            integer :: idex_element,idex_row, i, j
            
            do idex_row = 0, N-1
                i = idex_row
                do idex_element = A_rowp(i), A_rowp(i+1)-1
                    j = A_coli(idex_element)
                    if (i == j) then
                        invM(i) = 1.0d0 / A_v(idex_element)
                        ! write(*,'(2I8,1E30.15)') i, j,A_v(idex_element)
                    end if
                end do
            end do

        end subroutine diag
end module mod_kisti
