subroutine calc_rdf_fort(file_name, pbc_box, nr_mesh, r_cutoff, lateral, delta_z, sel_type, start_frame, stop_frame, step_frame)
! This subroutine calculates radial distribution function (RDF) between atoms
! (at this moment atoms with type) from .xyz output format via averaging over
! specified frames.
implicit none

    ! arguments
    character(LEN=15), intent(in) :: file_name
    real*8, intent(in) :: pbc_box(3)
    integer, intent(in) :: nr_mesh
    real*8, intent(in) :: r_cutoff, delta_z
    logical, intent(in) :: lateral
    character(LEN=15), intent(in) :: sel_type
    integer, intent(in) :: start_frame, stop_frame, step_frame

    INTEGER, PARAMETER :: MAXSIZE=200000, MESHSIZE=5000
    REAL*8, PARAMETER :: PI=3.141592d0

    ! local variables
    real*8 :: atoms_pos(MAXSIZE,3)
    character(LEN=15):: atoms_type(MAXSIZE)
    real*8 :: r(MESHSIZE), g_r(MESHSIZE)
    real*8 :: dr, rij, dx ,dy , dz, rho, box_vol
    integer :: natoms, i, j, nsel, ind, sel(MAXSIZE)
    integer :: current_frame, read_frame
    integer :: io

    ! opennig files
    open(1,file=trim(file_name), status='old')

    !write(*,*) '---------'
    !write(*,*) file_name
    !write(*,*) pbc_box
    !write(*,*) nr_mesh
    !write(*,*) r_cutoff
    !write(*,*) delta_z
    !write(*,*) lateral
    !write(*,*) sel_type
    !write(*,*) start_frame
    !write(*,*) stop_frame
    !write(*,*) step_frame
    !write(*,*) '---------'

    ! =======================

    dr = r_cutoff/float(nr_mesh)
    !write(*,*) dr

    do i = 1, nr_mesh+1
      r(i) = dr*(i-1);
    enddo

    ! initialize g(r) to zero
    g_r = 0.0d0

    ! =======================

    atoms_pos = 0.0d0
    read_frame = 0
    current_frame = 0

    do while (.true.)

        read(1, *, IOSTAT=io) natoms
        if (io.lt.0) exit
        read(1, *)  ! read comment line

        current_frame = current_frame + 1

        if (current_frame.ge.start_frame .and. mod(current_frame, step_frame).eq.0 .and. current_frame.le.stop_frame) then

            read_frame = read_frame + 1

            if (read_frame == 1) write(*,*) "N atoms:", natoms
            ! loop over all atoms and reading atomic types and positions
            do i = 1, natoms
                read(1,*) atoms_type(i), atoms_pos(i,1), atoms_pos(i,2), atoms_pos(i,3)
            enddo

            ! -------------------------------------

            nsel = 0
            do i = 1, natoms
              if( trim(atoms_type(i)) == sel_type ) then !atom selection
                nsel = nsel + 1
                sel(nsel) = i
              endif
            enddo

            !if (current_frame == start_frame) write(*,*) 'Selected atoms', nsel

            ! -------------------------------------

            do i = 1, nsel

              do j = 1, nsel

                    if (i == j) cycle  ! exclude self-counting

                    ! applying PBC
                    dx = atoms_pos(sel(i),1) - atoms_pos(sel(j),1)
                    call apply_pbc(pbc_box(1), dx)
                    ! ---
                    dy = atoms_pos(sel(i),2) - atoms_pos(sel(j),2)
                    call apply_pbc(pbc_box(2), dy)
                    ! ---
                    if (.not.lateral) then
                        dz = atoms_pos(sel(i),3) - atoms_pos(sel(j),3)
                        call apply_pbc(pbc_box(3), dz)
                    endif

                    ! ----------------------


                    if (.not.lateral) then
                        rij = sqrt( dx**2 + dy**2 + dz**2 )
                        if (rij.le.r_cutoff) then
                            ind = int(rij/dr) + 1
                            g_r(ind) = g_r(ind) + 1.d0
                        endif

                    else
                        if( abs(atoms_pos(sel(i),3) - atoms_pos(sel(j),3)) .lt. 0.5d0*delta_z ) then
                            rij = sqrt( dx**2 + dy**2 )
                            if (rij.le.r_cutoff) then
                                ind = int(rij/dr) + 1
                                g_r(ind)=g_r(ind) + 1.d0
                            endif
                        endif
                    endif

              enddo

            enddo

        else
            do i = 1, natoms ! natoms & comment line
                    read(1,*) !t, x, y, z
            enddo
        endif

    enddo
    close(1)

    !write(*,*) 'total frame', current_frame
    !write(*,*) 'frame equilibrium', start_frame
    !write(*,*) 'total readed frame', read_frame
    !Write(*,*) 'lateral RDF: ', lateral

    ! ------------------------------

    box_vol = pbc_box(1)*pbc_box(2)*pbc_box(3)
    rho = float(nsel)
    if (box_vol .gt. 1.0d-3) rho = rho/box_vol
    !write(*,*) "n-density", rho

    do i = 1, nr_mesh

      r(i) = (r(i)+r(i+1))*0.5d0
      g_r(i) = g_r(i)/read_frame

      if (.not.lateral) then
        g_r(i) = g_r(i)/( PI*4./3.*(r(i+1)**3-r(i)**3) )/rho/nsel/2

      else
        g_r(i) = g_r(i)/( PI*( r(i+1)**2-r(i)**2)*delta_z )/rho/nsel/2

      endif

    enddo

    ! ------------------------------

    open(4,file='gr.dat', status='unknown')
    do i = 1, nr_mesh
        write(4,'(2F16.7)') r(i), g_r(i)
    enddo
    close(4)

	! ------------------------------

    !write(*,*) "subroutine run succesfully."

end subroutine calc_rdf_fort


subroutine apply_pbc(length, dist)
    ! applying pbc along the specified direction
    implicit none

    real*8, intent(in) :: length
    real*8, intent(inout) :: dist

    if (length .gt. 1.0d-3) then  ! skip 0 size box length

        if (dist .gt.  length*0.5d0) dist = dist - length
        if (dist .lt. -length*0.5d0) dist = dist + length
    endif


end subroutine apply_pbc


!program radial_distribution_function
!implicit none
!
!    real*8 ::  pbc_box(3), r_cutoff, delta_z
!    integer :: nr_mesh, start_frame, stop_frame, step_frame
!    logical :: lateral
!    character(LEN=15) :: sel_type, file_name
!
!    pbc_box = (/19.246222, 19.246222, 19.246222/)
!    nr_mesh = 100
!    r_cutoff = 9.5
!    start_frame = 50
!    stop_frame = 201
!    step_frame = 1
!    lateral = .false.
!    delta_z = 1.0
!    sel_type = '2'
!    file_name = 'dump.xyz'
!
!    call calc_rdf_fort(file_name, pbc_box, nr_mesh, r_cutoff, lateral, delta_z, sel_type, start_frame, stop_frame, step_frame)
!
!end program radial_distribution_function