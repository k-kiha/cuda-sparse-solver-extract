program main
    use mod_kisti
    implicit none

    integer :: N,M
    real*8, allocatable :: b(:),x(:)
    type(mod_kisti_sparse_matrix_csr):: A

    integer :: unit,i
    real*8 :: t0, t1

    write(*,*) 'KISTI Ax=b Solver Tester'
    write(*,*) '-------------------------------------'

    write(*,'(1A)',advance='no') ':::::: init --'
    ! Part 0: 기타 준비
    open(newunit=unit, file='./Mtest/spmv_nm.txt', status='old', action='read')
    read(unit, *) N
    read(unit, *) M
    close(unit)

    ! Part A: 메모리 할당 및 초기화
    allocate(b(N),x(N)) 
    call mod_kisti_malloc     (N, M, A)
    call mod_kisti_gpumalloc_c(N, M)
  
    ! Part B: sparse matrix A 생성 (csr format), 우변 b 설정

    call mod_kisti_matrix_init(N, M, A, b, x)
    write(*,'(1A5)') '>DONE'
  
    ! BiCG solver 호출
    call cpu_time(t0)
    call mod_kisti_switch(N, M, A, b)
    call cpu_time(t1)
  
    ! Part C: 결과 확인 및 정리
    write(*,*) '-------------------------------------'
    write(*,*) 'Wtime(sec)           ::', t1-t0
    write(*,*) 'L2-norm(x(:),xref(:))::', sqrt(sum((x(:)-b(:))*(x(:)-b(:)))), sqrt(sum((x(:)-b(:))*(x(:)-b(:))))/N
    write(*,*) '-------------------------------------'


    open(newunit=unit, file='./result.txt')
    write(unit, '(A8,3A20)') "index", "xref", "x", "diff"
    write(unit, '(A8,3A20)') "------", "------", "------", "------"
    do i = 1, N
        write(unit, '(I8,3E20.12)') i, x(i), b(i), x(i)-b(i)
    end do
    close(unit)

  
    deallocate(b,x)
    call mod_kisti_malloc_delete     (A)
    call mod_kisti_gpumalloc_delete_c()
end program main