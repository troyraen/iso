program make_isochrone

  !MESA modules
  use utils_lib
  use interp_1d_def
  use interp_1d_lib

  !local modules
  use iso_eep_support

  implicit none

  character(len=8) :: version_string
  character(len=file_path) :: input_file, history_columns_list
  integer :: i, ierr, io, j, ntrk, ngood, first, prev, i_Minit
  type(track), allocatable :: s(:), t(:)
  type(isochrone_set) :: set
  real(dp) :: Fe_div_H, alpha_div_Fe, initial_Y, initial_Z, v_div_vcrit

  logical :: use_double_eep
  integer, parameter :: piecewise_monotonic = 4
  logical, parameter :: top_down = .true.

  !default some namelist parameters
  logical :: set_max_eep_number = .false.
  integer :: new_max_eep_number = -1
  logical :: iso_debug = .false.
  logical :: do_smooth = .true.
  logical :: do_PAV = .true.
  logical :: do_linear_interpolation = .false.
  real(dp) :: log_age_delta = 1d0
  namelist /iso_controls/ iso_debug, do_smooth, do_PAV, do_linear_interpolation, &
       log_age_delta, very_low_mass_limit, set_max_eep_number, new_max_eep_number

  !begin
  ierr=0
  if(command_argument_count()<1) then
     write(*,*) '   make_iso                   '
     write(*,*) '   usage: ./make_iso <input>  '
     stop       '   error: no command line argument provided'
  endif

  call read_iso_input(ierr)
  if(ierr/=0) write(*,*) '  read_iso_input: ierr = ', ierr

  !read eep files to fill s()
  first=ntrk
  prev=first
  ngood=0

  do i=1,ntrk
     call read_eep(s(i))
     if(s(i)% ignore) cycle
     if(i<first) then
        first=i             !this marks the first valid eep file
        prev=first
     elseif(prev>first)then
        prev=first
     endif
     if(iso_debug) write(*,'(a50,f8.2,99i8)') &
          trim(s(i)% filename), s(i)% initial_mass, s(i)% eep
     !check for monotonic mass, consistent phase info and version number
     if(ngood > 1)then
        if( s(i)% initial_mass < s(prev)% initial_mass ) &
             stop ' make_iso: masses out of order'
        if( s(i)% has_phase.neqv.s(prev)% has_phase ) &
             stop ' make_iso: inconsistent phase info in tracks'
        if( s(i)% MESA_revision_number /= s(prev)% MESA_revision_number )&
             stop ' make_iso: inconsistent version number in tracks'
     endif
     ngood=ngood+1
  enddo

  allocate(t(ngood))
  j=0
  do i=1,ntrk
     if(.not.s(i)% ignore) then
        j=j+1
        t(j)=s(i)
     endif
  enddo

  !above checks pass => these are safe assignments
  set% iso(:)% has_phase = t(1)% has_phase
  set% MESA_revision_number = t(1)% MESA_revision_number
  set% version_string = version_string
  set% Fe_div_H = Fe_div_H
  set% alpha_div_Fe = alpha_div_Fe
  set% initial_Y = initial_Y
  set% initial_Z = initial_Z
  set% v_div_vcrit = v_div_vcrit
  set% iso(:)% initial_Y = set% initial_Y
  set% iso(:)% initial_Z = set% initial_Z
  set% iso(:)% Fe_div_H  = set% Fe_div_H
  set% iso(:)% alpha_div_Fe = set% alpha_div_Fe
  set% iso(:)% v_div_vcrit = set% v_div_vcrit

  !create isochrones
  do i=1,set% number_of_isochrones
     call do_isochrone_for_age(t,set% iso(i),ierr)
     if (ierr/=0) exit
  enddo
  if(ierr==0)then
     call write_isochrones_to_file(set)
  else
     write(0,*) ' problem in make_iso: no output written'
  endif

  !all done.
  deallocate(s,t)

contains

  subroutine do_isochrone_for_age(s,iso,ierr)
    type(track), intent(in) :: s(:)
    type(isochrone), intent(inout) :: iso
    integer, intent(out) :: ierr
    integer :: eep, hi, index, interp_method, j, k, l, lo, max_eep, n, pass
    integer :: max_neep_low, max_neep_high, loc, khi, klo
    character(len=col_width) :: mass_age_string = 'mass from age'
    real(dp) :: age, mass, min_age, max_age, y(2)
    real(dp), pointer :: ages(:)=>NULL(), masses(:)=>NULL()
    real(dp), allocatable :: result1(:,:), result2(:,:), mass_tmp(:)
    logical, allocatable :: skip(:,:)
    integer, allocatable :: valid(:), count(:)
    real(dp), parameter :: tiny = 1d-12

    ierr = 0

    khi = 0
    klo = 0

    !initialize some quantities
    n = size(s) ! is the number of tracks
    max_eep = maxval(s(:)% ntrack) !is the largest number of EEPs in any track

    !allow more control over how many EEPs appear in an isochrone
    if(set_max_eep_number .and. new_max_eep_number > 0 .and. new_max_eep_number <= max_eep) then
       max_eep = new_max_eep_number
    endif

    allocate(skip(n,max_eep),count(max_eep))

    !set method and options for interpolation
    ! - for interp_m3: average, quartic, or super_bee
    !interp_method = average
    ! - for interp_pm: piecewise_monotonic
    interp_method = piecewise_monotonic

    if(iso% age_scale==age_scale_linear)then
       age = log10(iso% age)
    elseif(iso% age_scale==age_scale_log10)then
       age = iso% age
    endif
    mass=0d0

    !this is temporary storage for the isochrone data:
    !result1 stores the data for all EEPs, valid tells
    !which ones are good and will be returned via the iso
    !derived type
    allocate(result1(ncol,max_eep),result2(ncol,max_eep),valid(max_eep))
    result1 = 0d0
    result2 = 0d0
    valid = 0
    skip = .false.
    count = 0

    !determine the largest number of EEPs in tracks of different types
    max_neep_low = 0
    max_neep_high = 0
    do k=1,n
       if(s(k)% star_type < star_high_mass)then
          if(set_max_eep_number)then
             if(s(k)% eep(s(k)% neep) > new_max_eep_number) then
                do j=1,s(k)% neep
                   if(s(k)% eep(j) == new_max_eep_number) then
                      max_neep_low = j
                      exit
                   endif
                enddo
             else
                max_neep_low = max(max_neep_low, s(k)% neep)
             endif
          else
             max_neep_low = max(max_neep_low, s(k)% neep)
          endif
       else ! high-mass star
          if(set_max_eep_number)then
             if(s(k)% eep(s(k)% neep) > new_max_eep_number)then
                do j=1,s(k)% neep
                   if(s(k)% eep(j) == new_max_eep_number) then
                      max_neep_high = j
                      exit
                   endif
                enddo
             else
                max_neep_high = max(max_neep_high, s(k)% neep)
             endif
          else
             max_neep_high = max(max_neep_high, s(k)% neep)
          endif
       endif
    enddo

    !now check each track to make sure it is complete for its type
    do k=1,n
       if(s(k)% star_type == star_high_mass .and. s(k)% neep < max_neep_high) then
          skip(k,:) = .true.
       else if(s(k)% initial_mass > very_low_mass_limit &
            .and. s(k)% star_type == star_low_mass .and. s(k)% neep < max_neep_low) then
          skip(k,:) = .true.
       endif
    enddo

    max_age=age + log_age_delta
    min_age=age - log_age_delta

    eep_loop1: do eep=1,max_eep

       !determine tracks for which the ith eep is defined
       !the skip logical array determines whether or not a given
       !track will be included in the ensuing interpolation steps.
       !count keeps track of how many tracks will be used. if
       !fewer than 2 tracks satisfy the condition, skip the EEP
       do k=1,n
          if(s(k)% eep(1) > eep .or. s(k)% eep(s(k)% neep) < eep ) then
             skip(k,eep) = .true.
          else if(.not.use_double_eep .and. log10(s(k)% tr(i_age,eep)) > max_age ) then
             skip(k,eep) = .true.
          else if(.not.use_double_eep .and. log10(s(k)% tr(i_age,eep)) < min_age ) then
             skip(k,eep) = .true.
          endif
       enddo

       !this loop attempts to pick out non-monotonic points
       if(top_down)then
          if(.not.use_double_eep)then
             do k=n,2,-1
                if(skip(k,eep)) cycle
                do l=k-1,1
                   if( skip(l,eep)) cycle
                   if( s(k)% tr(i_age,eep) > s(l)% tr(i_age,eep) ) skip(l,eep) = .true.
                enddo
             enddo
          endif

       else !bottom-up

          if(.not.use_double_eep)then
             do k=1,n-1
                if(skip(k,eep)) cycle
                do l=k+1,n
                   if( skip(l,eep)) cycle
                   if( s(k)% tr(i_age,eep) < s(l)% tr(i_age,eep) ) skip(l,eep) = .true.
                enddo
             enddo
          endif

       endif


       !count tells the total number of valid tracks for each EEP
       do k=1,n
          if(.not.skip(k,eep)) count(eep)=count(eep)+1
       enddo

       if(iso_debug) write(*,*) '  EEP, count, n = ', eep, count(eep), n
       if(count(eep) < 2)then
          if(iso_debug) write(*,*) 'not enough eeps to interpolate'
          cycle eep_loop1
       endif

       !allocate ages and masses that pass the above test
       !I use pointers here because they can be allocated
       !and deallocated to the proper size for each EEP
       if(associated(ages)) then
          deallocate(ages)
          nullify(ages)
       endif
       if(associated(masses)) then
          deallocate(masses)
          nullify(masses)
       endif
       allocate(ages(count(eep)),masses(count(eep)))

       !this step fills the masses and ages arrays that are
       !used as the basis for interpolation
       j=0
       do k=1,n
          if(.not.skip(k,eep))then
             j=j+1
             ages(j) = log10(s(k)% tr(i_age,eep))
             masses(j) = s(k)% initial_mass
          endif
       enddo

       if(do_smooth.and.all(masses>very_low_mass_limit,dim=1)) call smooth(masses,ages)

       !check to see if the input age is found within the
       !current set of ages. if not, skip to the next EEP.
       khi = 0; klo = 0
       loc = binary_search( count(eep), ages, 1, age)
       if( loc < 1 .or. loc > count(eep)-1 ) cycle eep_loop1

       do k=1,n
          if(abs(masses(loc)-s(k)% initial_mass)<tiny)     klo = k
          if(abs(masses(loc+1) - s(k)% initial_mass)<tiny) khi = k
       enddo

       !check to see if masses and ages are monotonic
       !if not, then interpolation will fail
       if(.not.monotonic(masses)) then
          write(0,*) ' masses not monotonic in do_isochrone_for_age: ', age
          ierr=-1
          return
       endif

       if(iso_debug) then
          write(*,*) ' loc, count = ', loc, count(eep)
          write(*,*) skip(:,eep)
          do k=1,count(eep)
             write(*,*) masses(k), ages(k), age
          enddo
       endif

       !this block checks between two tracks at the current EEP to see if the
       !age lies in between the two. if it does, then it outputs a linear mass
       !interpolation. it is checking to see if this happens more than once.
       !j gives the number of times that this happens for a given EEP.
       if(use_double_eep)then
          pass=0
          k_loop: do k=1,count(eep)-1

             if(.not.skip(k,eep))then

                if( ages(k) > ages(k+1) .and. ages(k) >= age .and. ages(k+1) < age )then
                   pass = pass + 1
                   if(pass==1)then
                      call monotonic_mass_range(ages,k,lo,hi)
                      if(iso_debug) write(*,*) mass, masses(lo), masses(hi)

                      mass=interp_x_from_y(ages(lo:hi),masses(lo:hi),age,mass_age_string,ierr)
                      if(ierr/=0)then
                         write(0,*) ' age interpolation failed for eep, pass = ', eep, pass
                         cycle eep_loop1
                      endif

                      if(iso_debug) write(*,'(2i5,f9.5,3f14.9)') eep, pass, age, mass, masses(lo), masses(hi)

                      result1(i_Minit,eep) = mass
                      valid(eep)=1
                   else if(pass==2)then
                      call monotonic_mass_range(ages,k,lo,hi)
                      if(iso_debug) write(*,*) mass, masses(lo), masses(hi)

                      mass=interp_x_from_y(ages(lo:hi),masses(lo:hi),age,mass_age_string,ierr)
                      if(ierr/=0)then
                         write(0,*) ' age interpolation failed for eep, pass = ', eep, pass
                         cycle eep_loop1
                      endif

                      if(iso_debug) write(*,'(2i5,f9.5,3f14.9)') eep, pass, age, mass, masses(lo), masses(hi)

                      result2(i_Minit,eep) = mass
                      valid(eep)=2
                   endif

                endif

             endif

          enddo k_loop

       else ! single EEP case; this is the original method.
          ! interpolate in age to find the EEP's initial mass
          index = i_Minit     ! special case for iso_intepolate

          if(do_linear_interpolation)then
             mass = linear_interp(ages(loc:loc+1),masses(loc:loc+1),age)
          else
             mass = iso_interpolate( eep, interp_method, n, &
                  s, skip(:,eep), count(eep), index, ages, age, &
                  mass_age_string, ierr)
             if(ierr/=0)then
                write(0,*) ' interpolation failed in age->mass'
                cycle eep_loop1
             endif
          endif

          result1(i_Minit,eep) = mass
          valid(eep)=1
       endif

    enddo eep_loop1


    !PAV forces monotonicity in the masses
    if(do_PAV .and. .not.use_double_eep)then
       j=0
       allocate(mass_tmp(max_eep))
       do eep=1,max_eep
          if(valid(eep)>0) then
             j = j+1
             mass_tmp(j) = result1(i_Minit,eep)
          endif
       enddo

       call PAV(mass_tmp(1:j))

       j=0
       do eep=1,max_eep
          if(valid(eep)>0)then
             j=j+1
             result1(i_Minit,eep) = mass_tmp(j)
          endif
       enddo
       deallocate(mass_tmp)
    endif


    eep_loop2: do eep=1,max_eep

       if(count(eep)<2.or.valid(eep)<1) cycle eep_loop2

       !allocate ages and masses that pass the above test
       !I use pointers here because they can be allocated
       !and deallocated to the proper size for each EEP
       if(associated(ages)) then
          deallocate(ages)
          nullify(ages)
       endif
       if(associated(masses)) then
          deallocate(masses)
          nullify(masses)
       endif
       allocate(ages(count(eep)),masses(count(eep)))

       !this step fills the masses and ages arrays that are
       !used as the basis for interpolation
       j=0
       do k=1,n
          if(.not.skip(k,eep))then
             j=j+1
             ages(j) = log10(s(k)% tr(i_age,eep))
             masses(j) = s(k)% initial_mass
          endif
       enddo

       !check to see if the input age is found within the
       !current set of ages. if not, skip to the next EEP.
       khi = 0; klo = 0
       loc = binary_search( count(eep), ages, 1, age)
       if( loc < 1 .or. loc > count(eep)-1 ) cycle eep_loop2

       do k=1,n
          if(abs(masses(loc)-s(k)% initial_mass)<tiny)     klo = k
          if(abs(masses(loc+1) - s(k)% initial_mass)<tiny) khi = k
       enddo


       !this block checks between two tracks at the current EEP to see if the
       !age lies in between the two. if it does, then it outputs a linear mass
       !interpolation. it is checking to see if this happens more than once.
       !j gives the number of times that this happens for a given EEP.
       if(use_double_eep)then
          pass=0
          j_loop: do j=1,count(eep)-1

             if(.not.skip(j,eep))then

                if( ages(j) > ages(j+1) .and. ages(j) >= age .and. ages(j+1) < age )then
                   pass = pass + 1
                   if(pass==1)then

                      do index = 1, ncol
                         if(index==i_Minit) cycle
                         mass = result1(i_Minit,eep)
                         result1(index,eep) = iso_interpolate(eep, interp_method, n, &
                              s, skip(:,eep), count(eep), index, masses, mass, cols(index)% name, ierr)
                         if(ierr/=0) then
                            write(0,*) ' mass interpolation failed for index = ', &
                                 trim(cols(index)% name)
                            valid(eep)=0
                            cycle eep_loop2
                         endif
                      enddo
                      valid(eep)=1

                   else if(pass==2)then

                      do index = 1, ncol
                         if(index==i_Minit) cycle
                         mass = result2(i_Minit,eep)
                         result2(index,eep) = iso_interpolate(eep, interp_method, n, &
                              s, skip(:,eep), count(eep), index, masses, mass, cols(index)% name, ierr)
                         if(ierr/=0) then
                            write(0,*) ' mass interpolation failed for index = ', &
                                 trim(cols(index)% name)
                            valid(eep)=0
                            cycle eep_loop2
                         endif
                      enddo
                      valid(eep)=2
                   endif

                endif

             endif

          enddo j_loop


       else ! single EEP case; this is the original method.

          do index = 1, ncol
             if(index==i_Minit) cycle

             mass = result1(i_Minit,eep)

             y(1) = s(klo)% tr(index,eep)
             y(2) = s(khi)% tr(index,eep)

             if(do_linear_interpolation)then
                result1(index,eep) = linear_interp(masses(loc:loc+1), y, mass)
             else
                result1(index,eep) = iso_interpolate(eep, interp_method, n, &
                     s, skip(:,eep), count(eep), index, masses, mass, cols(index)% name, ierr)
                if(ierr/=0) then
                   write(0,*) ' mass interpolation failed for index = ', trim(cols(index)% name)
                   valid(eep)=0
                   cycle eep_loop2
                endif
             endif
          enddo
          valid(eep) = 1

       endif
    enddo eep_loop2

    if(associated(masses)) deallocate(masses)
    if(associated(ages)) deallocate(ages)


    !now result1 and valid are full for all EEPs,
    !we can pass the data to the iso derived type
    iso% ncol = ncol
    iso% neep = sum(valid)
    allocate(iso% cols(iso% ncol))
    allocate(iso% data(iso% ncol, iso% neep), iso% eep(iso% neep))
    if(iso% has_phase) allocate(iso% phase(iso% neep))

    iso% cols = cols

    j=0
    do eep=1,max_eep
       if(valid(eep)>0) then
          j=j+1
          iso% eep(j) = eep
          iso% data(:,j) = result1(:,eep)
          if(iso% has_phase)then
             do k=1,n-1
                if(iso% data(i_Minit,j) < s(k)% initial_mass) exit
             enddo
             iso% phase(j) = s(k)% phase(min(s(k)% ntrack,eep))
          endif
       endif

       if(valid(eep)==2) then
          j=j+1
          iso% eep(j) = eep
          iso% data(:,j) = result2(:,eep)
          if(iso% has_phase) then
             do k=1,n-1
                if(iso% data(i_Minit,j) < s(k)% initial_mass) exit
             enddo
             iso% phase(j) = s(k)% phase(min(s(k)% ntrack,eep))
          endif
       endif

    enddo

    !all done
    deallocate(result1,result2,skip,valid)

  end subroutine do_isochrone_for_age

  subroutine monotonic_mass_range(ages,k,lo,hi)
    !this subroutine determines the upper and lower limits that
    !should be used in the EEP interpolation for the case of
    !double EEPs; default result is lo=1, hi=size(ages)
    real(dp), intent(in) :: ages(:)
    integer, intent(in) :: k
    integer, intent(out) :: lo, hi
    integer :: j,n
    n=size(ages)
    !find lower limit:
    lo=1
    lower_loop: do j=k,1,-1
       if(ages(j+1) < ages(j)) then
          lo=j
       else
          exit lower_loop
       endif
    enddo lower_loop
    !find upper limit
    hi=n
    upper_loop: do j=lo+1,n
       if(ages(j-1) > ages(j)) then
          hi = j
       else
          exit upper_loop
       endif
    enddo upper_loop
  end subroutine monotonic_mass_range


  real(dp) function linear_interp(x,y,x_in)
    real(dp), intent(in) :: x(2), y(2), x_in
    real(dp) :: alfa, beta, dx
    dx = x(2) - x(1)
    alfa = (x(2) - x_in)/dx
    beta = (x_in - x(1))/dx
    linear_interp = alfa*y(1) + beta*y(2)
  end function linear_interp


  real(dp) function interp_x_from_y(x,y,x_in,label,ierr)
    real(dp), intent(in) :: x(:), y(:), x_in
    integer, parameter :: n_new = 1
    real(dp) :: x0(n_new), y0(n_new)
    real(dp), pointer :: work1(:)=>NULL()
    character(len=col_width), intent(in) :: label
    integer, intent(out) :: ierr
    integer :: n_old
    ierr=0
    if(size(x)/=size(y))then
       ierr=-1
       interp_x_from_y = 0d0
       return
    endif
    n_old = size(x)
    x0(n_new) = x_in
    allocate(work1(n_old*pm_work_size))
    call interpolate_vector_pm( n_old, x, n_new, x0, y, y0, work1, label, ierr )
    deallocate(work1)
    interp_x_from_y = y0(n_new)
  end function interp_x_from_y

  real(dp) function iso_interpolate(eep, method, n, s, skip, count, index, x_array, x, label, ierr)
    integer, intent(in) :: eep, method, n
    type(track), intent(in) :: s(n)
    logical, intent(in) :: skip(n)
    integer, intent(in) :: count, index
    real(dp), intent(in) :: x_array(count), x
    character(len=col_width), intent(in) :: label
    integer, intent(out) :: ierr
    integer :: j,k
    integer, parameter :: nwork = max(mp_work_size,pm_work_size)
    real(dp) :: y
    real(dp), target :: f_ary(4*count), work_ary(count*nwork)
    real(dp), pointer :: f1(:)=>NULL(), f(:,:)=>NULL(), work(:)=>NULL()

    ierr = 0
    iso_interpolate = 0d0

    !set up pointers for interpolation
    f1 => f_ary
    f(1:4,1:count) => f1(1:4*count)
    work => work_ary

    !check again that enough tracks are defined to interpolate
    if(count < 2) then
       ierr=-1
       return
    endif

    !fill the interpolant f(1,:)
    j=0
    do k=1,n
       if(.not.skip(k))then
          j=j+1
          if(index == i_Minit)then
             f(1,j) = s(k)% initial_mass
          else
             f(1,j) = s(k)% tr(index,eep)
          endif
       endif
    enddo

    !perform the interpolation, y~f(x), using the input method
    if(method == piecewise_monotonic)then
       call interp_pm(x_array,count,f1,nwork,work,label,ierr)
    else
       call interp_m3(x_array,count,f1,method,nwork,work,label,ierr)
    endif

    call interp_value(x_array,count,f1,x,y,ierr)

    if(is_bad_num(x) .or. is_bad_num(y))then
       write(0,*) ' eep = ', eep
       write(0,*) ' x = ', x
       write(0,*) ' y = ', y
       do k=1,n
          write(0,*) x_array(k), f(1,k), skip(k)
       enddo
       ierr=-1
    endif
    iso_interpolate = y

  end function iso_interpolate


  subroutine read_iso_input(ierr)
    integer, intent(out) :: ierr
    character(len=col_width) :: col_name
    character(len=10) :: list_type, age_type
    character(len=6) :: eep_style
    integer :: i, niso, age_scale
    real(dp) :: age_low, age_high, age_step
    ierr=0
    ntrk=0
    io=alloc_iounit(ierr)
    open(io, file='input.nml', action='read', status='old', iostat=ierr)
    read(io, nml=iso_controls, iostat=ierr)
    close(io)

    if(ierr/=0) then
       write(0,'(a)') 'make_iso: problem reading iso_controls namelist'
       return
    endif

    call get_command_argument(1,input_file)

    !read info about into tracks
    open(unit=io,file=trim(input_file),status='old',action='read',iostat=ierr)
    if(ierr/=0)then
       write(0,*) ' make_iso: problem reading ', trim(input_file)
       return
    endif
    read(io,*) !skip comment
    read(io,'(a8)') version_string
    read(io,*) !skip comment
    read(io,*) initial_Y, initial_Z, Fe_div_H, alpha_div_Fe, v_div_vcrit
    read(io,*) !skip comment
    read(io,'(a)') history_dir
    read(io,'(a)') eep_dir
    read(io,'(a)') iso_dir
    read(io,*) !skip comment
    read(io,'(a)') history_columns_list
    read(io,*) !skip comment
    read(io,*) ntrk
    allocate(s(ntrk))
    do i=1,ntrk
       read(io,'(a)',iostat=ierr) s(i)% filename
       s(i)% filename = trim(s(i)% filename)
       if(ierr/=0) exit
    enddo
    !read info about output isochrones
    read(io,*) !skip this line
    read(io,*) set% filename
    set% filename = trim(iso_dir) // '/' // trim(set% filename)
    read(io,'(a)') list_type
    read(io,'(a)') age_type
    if(trim(age_type)=='linear')then
       age_scale = age_scale_linear
    elseif(trim(age_type)=='log10')then
       age_scale = age_scale_log10
    else
       stop ' make_iso: age scale must be given as "linear" or "log10"'
    endif
    read(io,*) set% number_of_isochrones
    allocate(set% iso(set% number_of_isochrones))
    niso = set% number_of_isochrones
    if(trim(list_type)=='min_max') then
       read(io,*) age_low
       read(io,*) age_high
       if(age_high < age_low) stop '  make_iso: max age < min age'
       !assign ages
       if(niso > 1) then
          age_step = (age_high - age_low)/real(niso-1,kind=dp)
       else
          age_step = 0d0
       endif
       do i=1,niso
          set% iso(i)% age = age_low + age_step*real(i-1,kind=dp)
       enddo
    else if(trim(list_type)=='list') then
       do i=1,niso
          read(io,*) set% iso(i)% age
       enddo
    else
       stop ' make_iso: ages must be given as "list" or "min_max"'
    endif

    set% number_of_isochrones = niso
    do i=1,niso
       set% iso(i)% age_scale = age_scale
    enddo

    read(io,'(a6)',iostat=ierr) eep_style
    if(ierr==0 .and. eep_style=='double') then
       use_double_eep=.true.
    else
       use_double_eep=.false.
    endif
    close(io)
    call free_iounit(io)

    ! this section reads the column names to use from history_columns.list
    ! and locates those that need to be identified for isochrone construction
    call process_history_columns(history_columns_list,ierr)
    ncol = size(cols)

    col_name = 'star_age'; i_age = locate_column(col_name)
    !col_name = 'star_mass'; i_mass= locate_column(col_name)

    ! hack: replace star_age column with initial_mass in isochrones
    i_Minit = i_age
    cols(i_Minit)% name = 'initial_mass'

  end subroutine read_iso_input

  logical function monotonic(array)
    real(dp), intent(in) :: array(:)
    logical :: ascending = .false.
    integer :: i, n
    monotonic = .false.
    n = size(array)
    if(n<=2)then
       write(*,*) ' Warning, monotonic: array of length <= 2'
       write(*,*) 'array = ', array
    else
       ascending = array(1) <= array(n)
       if(ascending)then
          do i=1,n-1
             if(array(i) > array(i+1)) then
                if(iso_debug) write(*,*) array(i), ' > ', array(i+1)
                return
             endif
          enddo
       else !descending
          do i=1,n-1
             if(array(i) < array(i+1)) then
                if(iso_debug) write(*,*) array(i), ' > ', array(i+1)
                return
             endif
          enddo
       endif
    endif
    monotonic = .true.
  end function monotonic

!!$  subroutine check_monotonic(array,ierr)
!!$    real(dp), intent(in) :: array(:)
!!$    integer, intent(out) :: ierr
!!$    integer :: i
!!$    ierr=0
!!$    if(.not.monotonic(array))then
!!$       ierr=-1
!!$       write(*,*) ' array not monotonic '
!!$       do i=1,size(array)
!!$          write(*,*) i, array(i)
!!$       enddo
!!$    endif
!!$  end subroutine check_monotonic

  subroutine smooth(x,y)
    real(dp), intent(in) :: x(:)
    real(dp), intent(inout) :: y(:)
    integer :: i,n
    n=size(y)
    if(n<8) return
    y(2)=npoint(x(1:3),y(1:3),x(2))
    y(n-1)=npoint(x(n-2:n),y(n-2:n),x(n-1))
    do i=3,n-2
       y(i)=npoint(x(i-2:i+2),y(i-2:i+2),x(i))
    enddo
  end subroutine smooth

  function npoint(x,y,x0) result(y0)
    real(dp), intent(in)  :: x(:), y(:), x0
    real(dp) :: y0
    real(dp), allocatable :: w(:)
    real(dp), parameter :: eps=1d-1
    allocate(w(size(x)))
    w = 1d0/(eps+abs(x-x0))
    y0 = sum(y*w)/sum(w)
    deallocate(w)
  end function npoint

end program make_isochrone
