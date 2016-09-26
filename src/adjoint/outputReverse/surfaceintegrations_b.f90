!        generated by tapenade     (inria, tropics team)
!  tapenade 3.10 (r5363) -  9 sep 2014 09:53
!
module surfaceintegrations_b
  implicit none
! ----------------------------------------------------------------------
!                                                                      |
!                    no tapenade routine below this line               |
!                                                                      |
! ----------------------------------------------------------------------

contains
  subroutine integratesurfaces(localvalues)
! this is a shell routine that calls the specific surface
! integration routines. currently we have have the forceandmoment
! routine as well as the flow properties routine. this routine
! takes care of setting pointers, while the actual computational
! routine just acts on a specific fast pointed to by pointers. 
    use constants
    use blockpointers, only : nbocos, bcdata, bctype, sk, sj, si, x, &
&   rlv, sfacei, sfacej, sfacek, gamma, rev, p, viscsubface
    use surfacefamilies, only : famgroups
    use utils_b, only : setbcpointers, iswalltype
    use sorting, only : bsearchintegers
    use costfunctions, only : nlocalvalues
! tapenade needs to see these modules that the callees use.
    use bcpointers_b
    use flowvarrefstate
    use inputphysics
    implicit none
! input/output variables
    real(kind=realtype), dimension(nlocalvalues), intent(inout) :: &
&   localvalues
! working variables
    integer(kind=inttype) :: mm
! loop over all possible boundary conditions
bocos:do mm=1,nbocos
! determine if this boundary condition is to be incldued in the
! currently active group
      if (bsearchintegers(bcdata(mm)%famid, famgroups) .gt. 0) then
! set a bunch of pointers depending on the face id to make
! a generic treatment possible. 
        call setbcpointers(mm, .true.)
        if (iswalltype(bctype(mm))) call wallintegrationface(localvalues&
&                                                      , mm)
      end if
    end do bocos
  end subroutine integratesurfaces
  subroutine flowintegrationface(localvalues, mm)
    use constants
    use costfunctions
    use blockpointers, only : bcfaceid, bcdata, addgridvelocities
    use costfunctions, only : nlocalvalues, imassflow, imassptot, &
&   imassttot, imassps
    use sorting, only : bsearchintegers
    use flowvarrefstate, only : pref, rhoref, pref, timeref, lref, &
&   tref
    use inputphysics, only : pointref
    use flowutils_b, only : computeptot, computettot
    use bcpointers_b, only : ssi, sface, ww1, ww2, pp1, pp2, xx
    implicit none
! input/output variables
    real(kind=realtype), dimension(nlocalvalues), intent(inout) :: &
&   localvalues
    integer(kind=inttype), intent(in) :: mm
! local variables
    real(kind=realtype) :: massflowrate, mass_ptot, mass_ttot, mass_ps
    integer(kind=inttype) :: i, j, ii
    real(kind=realtype) :: fact, xc, yc, zc, cellarea, mx, my, mz
    real(kind=realtype) :: sf, vnm, vxm, vym, vzm, mredim, fx, fy, fz
    real(kind=realtype) :: pm, ptot, ttot, rhom, massflowratelocal
    real(kind=realtype), dimension(3) :: fp, mp, fmom, mmom, refpoint
    intrinsic sqrt
    intrinsic mod
    massflowrate = zero
    mass_ptot = zero
    mass_ttot = zero
    mass_ps = zero
    refpoint(1) = lref*pointref(1)
    refpoint(2) = lref*pointref(2)
    refpoint(3) = lref*pointref(3)
    select case  (bcfaceid(mm)) 
    case (imin, jmin, kmin) 
      fact = -one
    case (imax, jmax, kmax) 
      fact = one
    end select
! loop over the quadrilateral faces of the subface. note that
! the nodal range of bcdata must be used and not the cell
! range, because the latter may include the halo's in i and
! j-direction. the offset +1 is there, because inbeg and jnbeg
! refer to nodal ranges and not to cell ranges. the loop
! (without the ad stuff) would look like:
!
! do j=(bcdata(mm)%jnbeg+1),bcdata(mm)%jnend
!    do i=(bcdata(mm)%inbeg+1),bcdata(mm)%inend
    mredim = sqrt(pref*rhoref)
    fp = zero
    mp = zero
    fmom = zero
    mmom = zero
    do ii=0,(bcdata(mm)%jnend-bcdata(mm)%jnbeg)*(bcdata(mm)%inend-bcdata&
&       (mm)%inbeg)-1
      i = mod(ii, bcdata(mm)%inend - bcdata(mm)%inbeg) + bcdata(mm)%&
&       inbeg + 1
      j = ii/(bcdata(mm)%inend-bcdata(mm)%inbeg) + bcdata(mm)%jnbeg + 1
      if (addgridvelocities) then
        sf = sface(i, j)
      else
        sf = zero
      end if
      vxm = half*(ww1(i, j, ivx)+ww2(i, j, ivx))
      vym = half*(ww1(i, j, ivy)+ww2(i, j, ivy))
      vzm = half*(ww1(i, j, ivz)+ww2(i, j, ivz))
      rhom = half*(ww1(i, j, irho)+ww2(i, j, irho))
      pm = half*(pp1(i, j)+pp2(i, j))
      vnm = vxm*ssi(i, j, 1) + vym*ssi(i, j, 2) + vzm*ssi(i, j, 3) - sf
      call computeptot(rhom, vxm, vym, vzm, pm, ptot)
      call computettot(rhom, vxm, vym, vzm, pm, ttot)
      pm = pm*pref
      massflowratelocal = rhom*vnm*fact*mredim
      massflowrate = massflowrate + massflowratelocal
      mass_ptot = mass_ptot + ptot*massflowratelocal*pref
      mass_ttot = mass_ttot + ttot*massflowratelocal*tref
      mass_ps = mass_ps + pm*massflowratelocal
      xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1, &
&       1)) - refpoint(1)
      yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1, &
&       2)) - refpoint(2)
      zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1, &
&       3)) - refpoint(3)
! compute the force components.
! blk = max(bcdata(mm)%iblank(i,j), 0) ! iblank forces for overset stuff
      fx = pm*ssi(i, j, 1)
      fy = pm*ssi(i, j, 2)
      fz = pm*ssi(i, j, 3)
! pressure forces
! fx = fx*blk
! fy = fy*blk
! fz = fz*blk
! update the pressure force and moment coefficients.
      fp(1) = fp(1) + fx*fact
      fp(2) = fp(2) + fy*fact
      fp(3) = fp(3) + fz*fact
      mx = yc*fz - zc*fy
      my = zc*fx - xc*fz
      mz = xc*fy - yc*fx
      mp(1) = mp(1) + mx
      mp(2) = mp(2) + my
      mp(3) = mp(3) + mz
! momentum forces
      cellarea = sqrt(ssi(i, j, 1)**2 + ssi(i, j, 2)**2 + ssi(i, j, 3)**&
&       2)
      fx = massflowratelocal*bcdata(mm)%norm(i, j, 1)*vxm/timeref
      fy = massflowratelocal*bcdata(mm)%norm(i, j, 2)*vym/timeref
      fz = massflowratelocal*bcdata(mm)%norm(i, j, 3)*vzm/timeref
! fx = fx*blk
! fy = fy*blk
! fz = fz*block
! note: momentum forces have opposite sign to pressure forces
      fmom(1) = fmom(1) - fx*fact
      fmom(2) = fmom(2) - fy*fact
      fmom(3) = fmom(3) - fz*fact
      mx = yc*fz - zc*fy
      my = zc*fx - xc*fz
      mz = xc*fy - yc*fx
      mmom(1) = mmom(1) + mx
      mmom(2) = mmom(2) + my
      mmom(3) = mmom(3) + mz
    end do
! increment the local values array with what we computed here
    localvalues(imassflow) = localvalues(imassflow) + massflowrate
    localvalues(imassptot) = localvalues(imassptot) + mass_ptot
    localvalues(imassttot) = localvalues(imassttot) + mass_ttot
    localvalues(imassps) = localvalues(imassps) + mass_ps
    localvalues(iflowfp:iflowfp+2) = localvalues(iflowfp:iflowfp+2) + fp
    localvalues(iflowfm:iflowfm+2) = localvalues(iflowfm:iflowfm+2) + &
&     fmom
    localvalues(iflowmp:iflowmp+2) = localvalues(iflowmp:iflowmp+2) + mp
    localvalues(iflowmm:iflowmm+2) = localvalues(iflowmm:iflowmm+2) + &
&     mmom
  end subroutine flowintegrationface
!  differentiation of wallintegrationface in reverse (adjoint) mode (with options i4 dr8 r8 noisize):
!   gradient     of useful results: *(*viscsubface.tau) *(*bcdata.fv)
!                *(*bcdata.fp) *(*bcdata.area) veldirfreestream
!                machcoef pointref pinf pref *xx *pp1 *pp2 *ssi
!                *ww2 localvalues
!   with respect to varying inputs: *(*viscsubface.tau) *(*bcdata.fv)
!                *(*bcdata.fp) *(*bcdata.area) veldirfreestream
!                machcoef pointref pinf pref *xx *pp1 *pp2 *ssi
!                *ww2 localvalues
!   rw status of diff variables: *(*viscsubface.tau):incr *(*bcdata.fv):in-out
!                *(*bcdata.fp):in-out *(*bcdata.area):in-out veldirfreestream:incr
!                machcoef:incr pointref:incr pinf:incr pref:incr
!                *xx:incr *pp1:incr *pp2:incr *ssi:incr *ww2:incr
!                localvalues:in-out
!   plus diff mem management of: viscsubface:in *viscsubface.tau:in
!                bcdata:in *bcdata.fv:in *bcdata.fp:in *bcdata.area:in
!                xx:in pp1:in pp2:in ssi:in ww2:in
  subroutine wallintegrationface_b(localvalues, localvaluesd, mm)
!
!       wallintegrations computes the contribution of the block
!       given by the pointers in blockpointers to the force and
!       moment of the geometry. a distinction is made
!       between the inviscid and viscous parts. in case the maximum
!       yplus value must be monitored (only possible for rans), this
!       value is also computed. the separation sensor and the cavita-
!       tion sensor is also computed
!       here.
!
    use constants
    use costfunctions
    use communication
    use blockpointers
    use flowvarrefstate
    use inputphysics, only : machcoef, machcoefd, pointref, pointrefd,&
&   veldirfreestream, veldirfreestreamd, equations
    use costfunctions, only : nlocalvalues, ifp, ifv, imp, imv, &
&   isepsensor, isepavg, icavitation, sepsensorsharpness, &
&   sepsensoroffset, iyplus
    use sorting, only : bsearchintegers
    use bcpointers_b
    implicit none
! input/output variables
    real(kind=realtype), dimension(nlocalvalues), intent(inout) :: &
&   localvalues
    real(kind=realtype), dimension(nlocalvalues), intent(inout) :: &
&   localvaluesd
    integer(kind=inttype) :: mm
! local variables.
    real(kind=realtype), dimension(3) :: fp, fv, mp, mv
    real(kind=realtype), dimension(3) :: fpd, fvd, mpd, mvd
    real(kind=realtype) :: yplusmax, sepsensor, sepsensoravg(3), &
&   cavitation
    real(kind=realtype) :: sepsensord, sepsensoravgd(3), cavitationd
    integer(kind=inttype) :: i, j, ii, blk
    real(kind=realtype) :: pm1, fx, fy, fz, fn, sigma
    real(kind=realtype) :: pm1d, fxd, fyd, fzd
    real(kind=realtype) :: xc, yc, zc, qf(3)
    real(kind=realtype) :: xcd, ycd, zcd
    real(kind=realtype) :: fact, rho, mul, yplus, dwall
    real(kind=realtype) :: v(3), sensor, sensor1, cp, tmp, plocal
    real(kind=realtype) :: vd(3), sensord, sensor1d, cpd, tmpd, plocald
    real(kind=realtype) :: tauxx, tauyy, tauzz
    real(kind=realtype) :: tauxxd, tauyyd, tauzzd
    real(kind=realtype) :: tauxy, tauxz, tauyz
    real(kind=realtype) :: tauxyd, tauxzd, tauyzd
    real(kind=realtype), dimension(3) :: refpoint
    real(kind=realtype), dimension(3) :: refpointd
    real(kind=realtype) :: mx, my, mz, cellarea
    real(kind=realtype) :: mxd, myd, mzd, cellaread
    intrinsic mod
    intrinsic max
    intrinsic sqrt
    intrinsic exp
    real(kind=realtype), dimension(3) :: tmp0
    integer :: branch
    real(kind=realtype) :: temp3
    real(kind=realtype) :: tempd14
    real(kind=realtype) :: temp2
    real(kind=realtype) :: tempd13
    real(kind=realtype) :: temp1
    real(kind=realtype) :: tempd12
    real(kind=realtype) :: temp0
    real(kind=realtype) :: tempd11
    real(kind=realtype) :: tempd10
    real(kind=realtype) :: tempd9
    real(kind=realtype) :: tempd
    real(kind=realtype) :: tempd8
    real(kind=realtype) :: tempd7
    real(kind=realtype) :: tempd6(3)
    real(kind=realtype) :: tempd5
    real(kind=realtype) :: tempd4
    real(kind=realtype) :: tempd3
    real(kind=realtype) :: tempd2
    real(kind=realtype) :: tempd1
    real(kind=realtype) :: tempd0
    real(kind=realtype) :: tmpd0(3)
    real(kind=realtype) :: temp
    real(kind=realtype) :: temp5
    real(kind=realtype) :: temp4
    select case  (bcfaceid(mm)) 
    case (imin, jmin, kmin) 
      fact = -one
    case (imax, jmax, kmax) 
      fact = one
    end select
! determine the reference point for the moment computation in
! meters.
    refpoint(1) = lref*pointref(1)
    refpoint(2) = lref*pointref(2)
    refpoint(3) = lref*pointref(3)
! initialize the force and moment coefficients to 0 as well as
! yplusmax.
!
! integration of the viscous forces.
! only for viscous boundaries.
!
    if (bctype(mm) .eq. nswalladiabatic .or. bctype(mm) .eq. &
&       nswallisothermal) then
      call pushinteger4(i)
      call pushinteger4(j)
      call pushreal8(xc)
      call pushinteger4(blk)
      call pushreal8(yc)
      call pushreal8(zc)
      call pushreal8(fx)
      call pushreal8(fy)
      call pushreal8(fz)
      call pushcontrol1b(0)
    else
      call pushcontrol1b(1)
    end if
    sepsensoravgd = 0.0_8
    sepsensoravgd = localvaluesd(isepavg:isepavg+2)
    cavitationd = localvaluesd(icavitation)
    sepsensord = localvaluesd(isepsensor)
    mvd = 0.0_8
    mvd = localvaluesd(imv:imv+2)
    mpd = 0.0_8
    mpd = localvaluesd(imp:imp+2)
    fvd = 0.0_8
    fvd = localvaluesd(ifv:ifv+2)
    fpd = 0.0_8
    fpd = localvaluesd(ifp:ifp+2)
    call popcontrol1b(branch)
    if (branch .eq. 0) then
      refpointd = 0.0_8
      do ii=0,(bcdata(mm)%jnend-bcdata(mm)%jnbeg)*(bcdata(mm)%inend-&
&         bcdata(mm)%inbeg)-1
        i = mod(ii, bcdata(mm)%inend - bcdata(mm)%inbeg) + bcdata(mm)%&
&         inbeg + 1
        j = ii/(bcdata(mm)%inend-bcdata(mm)%inbeg) + bcdata(mm)%jnbeg + &
&         1
        if (bcdata(mm)%iblank(i, j) .lt. 0) then
          blk = 0
        else
          blk = bcdata(mm)%iblank(i, j)
        end if
        tauxx = viscsubface(mm)%tau(i, j, 1)
        tauyy = viscsubface(mm)%tau(i, j, 2)
        tauzz = viscsubface(mm)%tau(i, j, 3)
        tauxy = viscsubface(mm)%tau(i, j, 4)
        tauxz = viscsubface(mm)%tau(i, j, 5)
        tauyz = viscsubface(mm)%tau(i, j, 6)
! compute the viscous force on the face. a minus sign
! is now present, due to the definition of this force.
        fx = -(fact*(tauxx*ssi(i, j, 1)+tauxy*ssi(i, j, 2)+tauxz*ssi(i, &
&         j, 3))*pref)
        fy = -(fact*(tauxy*ssi(i, j, 1)+tauyy*ssi(i, j, 2)+tauyz*ssi(i, &
&         j, 3))*pref)
        fz = -(fact*(tauxz*ssi(i, j, 1)+tauyz*ssi(i, j, 2)+tauzz*ssi(i, &
&         j, 3))*pref)
! iblank forces after saving for zipper mesh
        fx = fx*blk
        fy = fy*blk
        fz = fz*blk
! compute the coordinates of the centroid of the face
! relative from the moment reference point. due to the
! usage of pointers for xx and offset of 1 is present,
! because x originally starts at 0.
        xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1&
&         , 1)) - refpoint(1)
        yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1&
&         , 2)) - refpoint(2)
        zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1&
&         , 3)) - refpoint(3)
! update the viscous force and moment coefficients.
! save the face based forces for the slice operations
! compute the tangential component of the stress tensor,
! which is needed to monitor y+. the result is stored
! in fx, fy, fz, although it is not really a force.
! as later on only the magnitude of the tangential
! component is important, there is no need to take the
! sign into account (it should be a minus sign).
        mxd = mvd(1)
        myd = mvd(2)
        mzd = mvd(3)
        fzd = fvd(3) - xc*myd + yc*mxd + bcdatad(mm)%fv(i, j, 3)
        bcdatad(mm)%fv(i, j, 3) = 0.0_8
        fyd = xc*mzd + fvd(2) - zc*mxd + bcdatad(mm)%fv(i, j, 2)
        bcdatad(mm)%fv(i, j, 2) = 0.0_8
        fxd = fvd(1) - yc*mzd + zc*myd + bcdatad(mm)%fv(i, j, 1)
        bcdatad(mm)%fv(i, j, 1) = 0.0_8
        xcd = fy*mzd - fz*myd
        ycd = fz*mxd - fx*mzd
        zcd = fx*myd - fy*mxd
        tempd9 = fourth*zcd
        xxd(i, j, 3) = xxd(i, j, 3) + tempd9
        xxd(i+1, j, 3) = xxd(i+1, j, 3) + tempd9
        xxd(i, j+1, 3) = xxd(i, j+1, 3) + tempd9
        xxd(i+1, j+1, 3) = xxd(i+1, j+1, 3) + tempd9
        refpointd(3) = refpointd(3) - zcd
        tempd10 = fourth*ycd
        xxd(i, j, 2) = xxd(i, j, 2) + tempd10
        xxd(i+1, j, 2) = xxd(i+1, j, 2) + tempd10
        xxd(i, j+1, 2) = xxd(i, j+1, 2) + tempd10
        xxd(i+1, j+1, 2) = xxd(i+1, j+1, 2) + tempd10
        refpointd(2) = refpointd(2) - ycd
        tempd11 = fourth*xcd
        xxd(i, j, 1) = xxd(i, j, 1) + tempd11
        xxd(i+1, j, 1) = xxd(i+1, j, 1) + tempd11
        xxd(i, j+1, 1) = xxd(i, j+1, 1) + tempd11
        xxd(i+1, j+1, 1) = xxd(i+1, j+1, 1) + tempd11
        refpointd(1) = refpointd(1) - xcd
        fzd = blk*fzd
        fyd = blk*fyd
        fxd = blk*fxd
        tempd12 = -(fact*pref*fzd)
        ssid(i, j, 1) = ssid(i, j, 1) + tauxz*tempd12
        ssid(i, j, 2) = ssid(i, j, 2) + tauyz*tempd12
        tauzzd = ssi(i, j, 3)*tempd12
        ssid(i, j, 3) = ssid(i, j, 3) + tauzz*tempd12
        prefd = prefd - fact*(tauxz*ssi(i, j, 1)+tauyz*ssi(i, j, 2)+&
&         tauzz*ssi(i, j, 3))*fzd
        tempd14 = -(fact*pref*fyd)
        tauyzd = ssi(i, j, 3)*tempd14 + ssi(i, j, 2)*tempd12
        ssid(i, j, 1) = ssid(i, j, 1) + tauxy*tempd14
        tauyyd = ssi(i, j, 2)*tempd14
        ssid(i, j, 2) = ssid(i, j, 2) + tauyy*tempd14
        ssid(i, j, 3) = ssid(i, j, 3) + tauyz*tempd14
        prefd = prefd - fact*(tauxy*ssi(i, j, 1)+tauyy*ssi(i, j, 2)+&
&         tauyz*ssi(i, j, 3))*fyd
        tempd13 = -(fact*pref*fxd)
        tauxzd = ssi(i, j, 3)*tempd13 + ssi(i, j, 1)*tempd12
        tauxyd = ssi(i, j, 2)*tempd13 + ssi(i, j, 1)*tempd14
        tauxxd = ssi(i, j, 1)*tempd13
        ssid(i, j, 1) = ssid(i, j, 1) + tauxx*tempd13
        ssid(i, j, 2) = ssid(i, j, 2) + tauxy*tempd13
        ssid(i, j, 3) = ssid(i, j, 3) + tauxz*tempd13
        prefd = prefd - fact*(tauxx*ssi(i, j, 1)+tauxy*ssi(i, j, 2)+&
&         tauxz*ssi(i, j, 3))*fxd
        viscsubfaced(mm)%tau(i, j, 6) = viscsubfaced(mm)%tau(i, j, 6) + &
&         tauyzd
        viscsubfaced(mm)%tau(i, j, 5) = viscsubfaced(mm)%tau(i, j, 5) + &
&         tauxzd
        viscsubfaced(mm)%tau(i, j, 4) = viscsubfaced(mm)%tau(i, j, 4) + &
&         tauxyd
        viscsubfaced(mm)%tau(i, j, 3) = viscsubfaced(mm)%tau(i, j, 3) + &
&         tauzzd
        viscsubfaced(mm)%tau(i, j, 2) = viscsubfaced(mm)%tau(i, j, 2) + &
&         tauyyd
        viscsubfaced(mm)%tau(i, j, 1) = viscsubfaced(mm)%tau(i, j, 1) + &
&         tauxxd
      end do
      call popreal8(fz)
      call popreal8(fy)
      call popreal8(fx)
      call popreal8(zc)
      call popreal8(yc)
      call popinteger4(blk)
      call popreal8(xc)
      call popinteger4(j)
      call popinteger4(i)
    else
      bcdatad(mm)%fv = 0.0_8
      refpointd = 0.0_8
    end if
    vd = 0.0_8
    do ii=0,(bcdata(mm)%jnend-bcdata(mm)%jnbeg)*(bcdata(mm)%inend-bcdata&
&       (mm)%inbeg)-1
      i = mod(ii, bcdata(mm)%inend - bcdata(mm)%inbeg) + bcdata(mm)%&
&       inbeg + 1
      j = ii/(bcdata(mm)%inend-bcdata(mm)%inbeg) + bcdata(mm)%jnbeg + 1
! compute the average pressure minus 1 and the coordinates
! of the centroid of the face relative from from the
! moment reference point. due to the usage of pointers for
! the coordinates, whose original array starts at 0, an
! offset of 1 must be used. the pressure is multipled by
! fact to account for the possibility of an inward or
! outward pointing normal.
      pm1 = fact*(half*(pp2(i, j)+pp1(i, j))-pinf)*pref
      xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1, &
&       1)) - refpoint(1)
      yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1, &
&       2)) - refpoint(2)
      zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1, &
&       3)) - refpoint(3)
      if (bcdata(mm)%iblank(i, j) .lt. 0) then
        blk = 0
      else
        blk = bcdata(mm)%iblank(i, j)
      end if
      fx = pm1*ssi(i, j, 1)
      fy = pm1*ssi(i, j, 2)
      fz = pm1*ssi(i, j, 3)
! iblank forces
      fx = fx*blk
      fy = fy*blk
      fz = fz*blk
! update the inviscid force and moment coefficients.
! save the face-based forces and area
      cellarea = sqrt(ssi(i, j, 1)**2 + ssi(i, j, 2)**2 + ssi(i, j, 3)**&
&       2)
! get normalized surface velocity:
      v(1) = ww2(i, j, ivx)
      v(2) = ww2(i, j, ivy)
      v(3) = ww2(i, j, ivz)
      tmp0 = v/(sqrt(v(1)**2+v(2)**2+v(3)**2)+1e-16)
      call pushreal8array(v, 3)
      v = tmp0
! dot product with free stream
      sensor = -(v(1)*veldirfreestream(1)+v(2)*veldirfreestream(2)+v(3)*&
&       veldirfreestream(3))
!now run through a smooth heaviside function:
      call pushreal8(sensor)
      sensor = one/(one+exp(-(2*sepsensorsharpness*(sensor-&
&       sepsensoroffset))))
! and integrate over the area of this cell and save:
      call pushreal8(sensor)
      sensor = sensor*cellarea
! also accumulate into the sepsensoravg
      call pushreal8(xc)
      xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1, &
&       1))
      call pushreal8(yc)
      yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1, &
&       2))
      call pushreal8(zc)
      zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1, &
&       3))
      plocal = pp2(i, j)
      tmp = two/(gammainf*machcoef*machcoef)
      cp = tmp*(plocal-pinf)
      sigma = 1.4
      sensor1 = -cp - sigma
      call pushreal8(sensor1)
      sensor1 = one/(one+exp(-(2*10*sensor1)))
      mxd = mpd(1)
      myd = mpd(2)
      mzd = mpd(3)
      sensor1d = cavitationd
      cellaread = sensor1*sensor1d
      sensor1d = cellarea*sensor1d
      call popreal8(sensor1)
      temp5 = -(10*2*sensor1)
      temp4 = one + exp(temp5)
      sensor1d = exp(temp5)*one*10*2*sensor1d/temp4**2
      cpd = -sensor1d
      tmpd = (plocal-pinf)*cpd
      plocald = tmp*cpd
      pinfd = pinfd - tmp*cpd
      temp3 = gammainf*machcoef**2
      machcoefd = machcoefd - gammainf*two*2*machcoef*tmpd/temp3**2
      pp2d(i, j) = pp2d(i, j) + plocald
      sensord = yc*sepsensoravgd(2) + sepsensord + xc*sepsensoravgd(1) +&
&       zc*sepsensoravgd(3)
      zcd = sensor*sepsensoravgd(3)
      ycd = sensor*sepsensoravgd(2)
      xcd = sensor*sepsensoravgd(1)
      call popreal8(zc)
      tempd3 = fourth*zcd
      xxd(i, j, 3) = xxd(i, j, 3) + tempd3
      xxd(i+1, j, 3) = xxd(i+1, j, 3) + tempd3
      xxd(i, j+1, 3) = xxd(i, j+1, 3) + tempd3
      xxd(i+1, j+1, 3) = xxd(i+1, j+1, 3) + tempd3
      call popreal8(yc)
      tempd4 = fourth*ycd
      xxd(i, j, 2) = xxd(i, j, 2) + tempd4
      xxd(i+1, j, 2) = xxd(i+1, j, 2) + tempd4
      xxd(i, j+1, 2) = xxd(i, j+1, 2) + tempd4
      xxd(i+1, j+1, 2) = xxd(i+1, j+1, 2) + tempd4
      call popreal8(xc)
      tempd5 = fourth*xcd
      xxd(i, j, 1) = xxd(i, j, 1) + tempd5
      xxd(i+1, j, 1) = xxd(i+1, j, 1) + tempd5
      xxd(i, j+1, 1) = xxd(i, j+1, 1) + tempd5
      xxd(i+1, j+1, 1) = xxd(i+1, j+1, 1) + tempd5
      call popreal8(sensor)
      cellaread = cellaread + sensor*sensord
      sensord = cellarea*sensord
      call popreal8(sensor)
      temp2 = -(2*sepsensorsharpness*(sensor-sepsensoroffset))
      temp1 = one + exp(temp2)
      sensord = exp(temp2)*one*sepsensorsharpness*2*sensord/temp1**2
      vd(1) = vd(1) - veldirfreestream(1)*sensord
      veldirfreestreamd(1) = veldirfreestreamd(1) - v(1)*sensord
      vd(2) = vd(2) - veldirfreestream(2)*sensord
      veldirfreestreamd(2) = veldirfreestreamd(2) - v(2)*sensord
      vd(3) = vd(3) - veldirfreestream(3)*sensord
      veldirfreestreamd(3) = veldirfreestreamd(3) - v(3)*sensord
      call popreal8array(v, 3)
      tmpd0 = vd
      temp = v(1)**2 + v(2)**2 + v(3)**2
      temp0 = sqrt(temp)
      tempd6 = tmpd0/(temp0+1e-16)
      vd = tempd6
      if (temp .eq. 0.0_8) then
        tempd7 = 0.0
      else
        tempd7 = sum(-(v*tempd6/(temp0+1e-16)))/(2.0*temp0)
      end if
      vd(1) = vd(1) + 2*v(1)*tempd7
      vd(2) = vd(2) + 2*v(2)*tempd7
      vd(3) = vd(3) + 2*v(3)*tempd7
      ww2d(i, j, ivz) = ww2d(i, j, ivz) + vd(3)
      vd(3) = 0.0_8
      ww2d(i, j, ivy) = ww2d(i, j, ivy) + vd(2)
      vd(2) = 0.0_8
      ww2d(i, j, ivx) = ww2d(i, j, ivx) + vd(1)
      vd(1) = 0.0_8
      cellaread = cellaread + bcdatad(mm)%area(i, j)
      bcdatad(mm)%area(i, j) = 0.0_8
      if (ssi(i, j, 1)**2 + ssi(i, j, 2)**2 + ssi(i, j, 3)**2 .eq. 0.0_8&
&     ) then
        tempd8 = 0.0
      else
        tempd8 = cellaread/(2.0*sqrt(ssi(i, j, 1)**2+ssi(i, j, 2)**2+ssi&
&         (i, j, 3)**2))
      end if
      ssid(i, j, 1) = ssid(i, j, 1) + 2*ssi(i, j, 1)*tempd8
      ssid(i, j, 2) = ssid(i, j, 2) + 2*ssi(i, j, 2)*tempd8
      ssid(i, j, 3) = ssid(i, j, 3) + 2*ssi(i, j, 3)*tempd8
      fzd = fpd(3) - xc*myd + yc*mxd + bcdatad(mm)%fp(i, j, 3)
      bcdatad(mm)%fp(i, j, 3) = 0.0_8
      fyd = xc*mzd + fpd(2) - zc*mxd + bcdatad(mm)%fp(i, j, 2)
      bcdatad(mm)%fp(i, j, 2) = 0.0_8
      fxd = fpd(1) - yc*mzd + zc*myd + bcdatad(mm)%fp(i, j, 1)
      bcdatad(mm)%fp(i, j, 1) = 0.0_8
      xcd = fy*mzd - fz*myd
      ycd = fz*mxd - fx*mzd
      zcd = fx*myd - fy*mxd
      fzd = blk*fzd
      fyd = blk*fyd
      fxd = blk*fxd
      pm1d = ssi(i, j, 2)*fyd + ssi(i, j, 1)*fxd + ssi(i, j, 3)*fzd
      ssid(i, j, 3) = ssid(i, j, 3) + pm1*fzd
      ssid(i, j, 2) = ssid(i, j, 2) + pm1*fyd
      ssid(i, j, 1) = ssid(i, j, 1) + pm1*fxd
      tempd = fourth*zcd
      xxd(i, j, 3) = xxd(i, j, 3) + tempd
      xxd(i+1, j, 3) = xxd(i+1, j, 3) + tempd
      xxd(i, j+1, 3) = xxd(i, j+1, 3) + tempd
      xxd(i+1, j+1, 3) = xxd(i+1, j+1, 3) + tempd
      refpointd(3) = refpointd(3) - zcd
      tempd0 = fourth*ycd
      xxd(i, j, 2) = xxd(i, j, 2) + tempd0
      xxd(i+1, j, 2) = xxd(i+1, j, 2) + tempd0
      xxd(i, j+1, 2) = xxd(i, j+1, 2) + tempd0
      xxd(i+1, j+1, 2) = xxd(i+1, j+1, 2) + tempd0
      refpointd(2) = refpointd(2) - ycd
      tempd1 = fourth*xcd
      xxd(i, j, 1) = xxd(i, j, 1) + tempd1
      xxd(i+1, j, 1) = xxd(i+1, j, 1) + tempd1
      xxd(i, j+1, 1) = xxd(i, j+1, 1) + tempd1
      xxd(i+1, j+1, 1) = xxd(i+1, j+1, 1) + tempd1
      refpointd(1) = refpointd(1) - xcd
      tempd2 = fact*pref*pm1d
      pp2d(i, j) = pp2d(i, j) + half*tempd2
      pp1d(i, j) = pp1d(i, j) + half*tempd2
      pinfd = pinfd - tempd2
      prefd = prefd + fact*(half*(pp2(i, j)+pp1(i, j))-pinf)*pm1d
    end do
    pointrefd(3) = pointrefd(3) + lref*refpointd(3)
    refpointd(3) = 0.0_8
    pointrefd(2) = pointrefd(2) + lref*refpointd(2)
    refpointd(2) = 0.0_8
    pointrefd(1) = pointrefd(1) + lref*refpointd(1)
  end subroutine wallintegrationface_b
  subroutine wallintegrationface(localvalues, mm)
!
!       wallintegrations computes the contribution of the block
!       given by the pointers in blockpointers to the force and
!       moment of the geometry. a distinction is made
!       between the inviscid and viscous parts. in case the maximum
!       yplus value must be monitored (only possible for rans), this
!       value is also computed. the separation sensor and the cavita-
!       tion sensor is also computed
!       here.
!
    use constants
    use costfunctions
    use communication
    use blockpointers
    use flowvarrefstate
    use inputphysics, only : machcoef, pointref, veldirfreestream, &
&   equations
    use costfunctions, only : nlocalvalues, ifp, ifv, imp, imv, &
&   isepsensor, isepavg, icavitation, sepsensorsharpness, &
&   sepsensoroffset, iyplus
    use sorting, only : bsearchintegers
    use bcpointers_b
    implicit none
! input/output variables
    real(kind=realtype), dimension(nlocalvalues), intent(inout) :: &
&   localvalues
    integer(kind=inttype) :: mm
! local variables.
    real(kind=realtype), dimension(3) :: fp, fv, mp, mv
    real(kind=realtype) :: yplusmax, sepsensor, sepsensoravg(3), &
&   cavitation
    integer(kind=inttype) :: i, j, ii, blk
    real(kind=realtype) :: pm1, fx, fy, fz, fn, sigma
    real(kind=realtype) :: xc, yc, zc, qf(3)
    real(kind=realtype) :: fact, rho, mul, yplus, dwall
    real(kind=realtype) :: v(3), sensor, sensor1, cp, tmp, plocal
    real(kind=realtype) :: tauxx, tauyy, tauzz
    real(kind=realtype) :: tauxy, tauxz, tauyz
    real(kind=realtype), dimension(3) :: refpoint
    real(kind=realtype) :: mx, my, mz, cellarea
    intrinsic mod
    intrinsic max
    intrinsic sqrt
    intrinsic exp
    select case  (bcfaceid(mm)) 
    case (imin, jmin, kmin) 
      fact = -one
    case (imax, jmax, kmax) 
      fact = one
    end select
! determine the reference point for the moment computation in
! meters.
    refpoint(1) = lref*pointref(1)
    refpoint(2) = lref*pointref(2)
    refpoint(3) = lref*pointref(3)
! initialize the force and moment coefficients to 0 as well as
! yplusmax.
    fp = zero
    fv = zero
    mp = zero
    mv = zero
    yplusmax = zero
    sepsensor = zero
    cavitation = zero
    sepsensoravg = zero
!
!         integrate the inviscid contribution over the solid walls,
!         either inviscid or viscous. the integration is done with
!         cp. for closed contours this is equal to the integration
!         of p; for open contours this is not the case anymore.
!         question is whether a force for an open contour is
!         meaningful anyway.
!
! loop over the quadrilateral faces of the subface. note that
! the nodal range of bcdata must be used and not the cell
! range, because the latter may include the halo's in i and
! j-direction. the offset +1 is there, because inbeg and jnbeg
! refer to nodal ranges and not to cell ranges. the loop
! (without the ad stuff) would look like:
!
! do j=(bcdata(mm)%jnbeg+1),bcdata(mm)%jnend
!    do i=(bcdata(mm)%inbeg+1),bcdata(mm)%inend
    do ii=0,(bcdata(mm)%jnend-bcdata(mm)%jnbeg)*(bcdata(mm)%inend-bcdata&
&       (mm)%inbeg)-1
      i = mod(ii, bcdata(mm)%inend - bcdata(mm)%inbeg) + bcdata(mm)%&
&       inbeg + 1
      j = ii/(bcdata(mm)%inend-bcdata(mm)%inbeg) + bcdata(mm)%jnbeg + 1
! compute the average pressure minus 1 and the coordinates
! of the centroid of the face relative from from the
! moment reference point. due to the usage of pointers for
! the coordinates, whose original array starts at 0, an
! offset of 1 must be used. the pressure is multipled by
! fact to account for the possibility of an inward or
! outward pointing normal.
      pm1 = fact*(half*(pp2(i, j)+pp1(i, j))-pinf)*pref
      xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1, &
&       1)) - refpoint(1)
      yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1, &
&       2)) - refpoint(2)
      zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1, &
&       3)) - refpoint(3)
      if (bcdata(mm)%iblank(i, j) .lt. 0) then
        blk = 0
      else
        blk = bcdata(mm)%iblank(i, j)
      end if
      fx = pm1*ssi(i, j, 1)
      fy = pm1*ssi(i, j, 2)
      fz = pm1*ssi(i, j, 3)
! iblank forces
      fx = fx*blk
      fy = fy*blk
      fz = fz*blk
! update the inviscid force and moment coefficients.
      fp(1) = fp(1) + fx
      fp(2) = fp(2) + fy
      fp(3) = fp(3) + fz
      mx = yc*fz - zc*fy
      my = zc*fx - xc*fz
      mz = xc*fy - yc*fx
      mp(1) = mp(1) + mx
      mp(2) = mp(2) + my
      mp(3) = mp(3) + mz
! save the face-based forces and area
      bcdata(mm)%fp(i, j, 1) = fx
      bcdata(mm)%fp(i, j, 2) = fy
      bcdata(mm)%fp(i, j, 3) = fz
      cellarea = sqrt(ssi(i, j, 1)**2 + ssi(i, j, 2)**2 + ssi(i, j, 3)**&
&       2)
      bcdata(mm)%area(i, j) = cellarea
! get normalized surface velocity:
      v(1) = ww2(i, j, ivx)
      v(2) = ww2(i, j, ivy)
      v(3) = ww2(i, j, ivz)
      v = v/(sqrt(v(1)**2+v(2)**2+v(3)**2)+1e-16)
! dot product with free stream
      sensor = -(v(1)*veldirfreestream(1)+v(2)*veldirfreestream(2)+v(3)*&
&       veldirfreestream(3))
!now run through a smooth heaviside function:
      sensor = one/(one+exp(-(2*sepsensorsharpness*(sensor-&
&       sepsensoroffset))))
! and integrate over the area of this cell and save:
      sensor = sensor*cellarea
      sepsensor = sepsensor + sensor
! also accumulate into the sepsensoravg
      xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1, &
&       1))
      yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1, &
&       2))
      zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1, &
&       3))
      sepsensoravg(1) = sepsensoravg(1) + sensor*xc
      sepsensoravg(2) = sepsensoravg(2) + sensor*yc
      sepsensoravg(3) = sepsensoravg(3) + sensor*zc
      plocal = pp2(i, j)
      tmp = two/(gammainf*machcoef*machcoef)
      cp = tmp*(plocal-pinf)
      sigma = 1.4
      sensor1 = -cp - sigma
      sensor1 = one/(one+exp(-(2*10*sensor1)))
      sensor1 = sensor1*cellarea
      cavitation = cavitation + sensor1
    end do
!
! integration of the viscous forces.
! only for viscous boundaries.
!
    if (bctype(mm) .eq. nswalladiabatic .or. bctype(mm) .eq. &
&       nswallisothermal) then
! initialize dwall for the laminar case and set the pointer
! for the unit normals.
      dwall = zero
! loop over the quadrilateral faces of the subface and
! compute the viscous contribution to the force and
! moment and update the maximum value of y+.
      do ii=0,(bcdata(mm)%jnend-bcdata(mm)%jnbeg)*(bcdata(mm)%inend-&
&         bcdata(mm)%inbeg)-1
        i = mod(ii, bcdata(mm)%inend - bcdata(mm)%inbeg) + bcdata(mm)%&
&         inbeg + 1
        j = ii/(bcdata(mm)%inend-bcdata(mm)%inbeg) + bcdata(mm)%jnbeg + &
&         1
        if (bcdata(mm)%iblank(i, j) .lt. 0) then
          blk = 0
        else
          blk = bcdata(mm)%iblank(i, j)
        end if
        tauxx = viscsubface(mm)%tau(i, j, 1)
        tauyy = viscsubface(mm)%tau(i, j, 2)
        tauzz = viscsubface(mm)%tau(i, j, 3)
        tauxy = viscsubface(mm)%tau(i, j, 4)
        tauxz = viscsubface(mm)%tau(i, j, 5)
        tauyz = viscsubface(mm)%tau(i, j, 6)
! compute the viscous force on the face. a minus sign
! is now present, due to the definition of this force.
        fx = -(fact*(tauxx*ssi(i, j, 1)+tauxy*ssi(i, j, 2)+tauxz*ssi(i, &
&         j, 3))*pref)
        fy = -(fact*(tauxy*ssi(i, j, 1)+tauyy*ssi(i, j, 2)+tauyz*ssi(i, &
&         j, 3))*pref)
        fz = -(fact*(tauxz*ssi(i, j, 1)+tauyz*ssi(i, j, 2)+tauzz*ssi(i, &
&         j, 3))*pref)
! iblank forces after saving for zipper mesh
        tauxx = tauxx*blk
        tauyy = tauyy*blk
        tauzz = tauzz*blk
        tauxy = tauxy*blk
        tauxz = tauxz*blk
        tauyz = tauyz*blk
        fx = fx*blk
        fy = fy*blk
        fz = fz*blk
! compute the coordinates of the centroid of the face
! relative from the moment reference point. due to the
! usage of pointers for xx and offset of 1 is present,
! because x originally starts at 0.
        xc = fourth*(xx(i, j, 1)+xx(i+1, j, 1)+xx(i, j+1, 1)+xx(i+1, j+1&
&         , 1)) - refpoint(1)
        yc = fourth*(xx(i, j, 2)+xx(i+1, j, 2)+xx(i, j+1, 2)+xx(i+1, j+1&
&         , 2)) - refpoint(2)
        zc = fourth*(xx(i, j, 3)+xx(i+1, j, 3)+xx(i, j+1, 3)+xx(i+1, j+1&
&         , 3)) - refpoint(3)
! update the viscous force and moment coefficients.
        fv(1) = fv(1) + fx
        fv(2) = fv(2) + fy
        fv(3) = fv(3) + fz
        mx = yc*fz - zc*fy
        my = zc*fx - xc*fz
        mz = xc*fy - yc*fx
        mv(1) = mv(1) + mx
        mv(2) = mv(2) + my
        mv(3) = mv(3) + mz
! save the face based forces for the slice operations
        bcdata(mm)%fv(i, j, 1) = fx
        bcdata(mm)%fv(i, j, 2) = fy
        bcdata(mm)%fv(i, j, 3) = fz
! compute the tangential component of the stress tensor,
! which is needed to monitor y+. the result is stored
! in fx, fy, fz, although it is not really a force.
! as later on only the magnitude of the tangential
! component is important, there is no need to take the
! sign into account (it should be a minus sign).
        fx = tauxx*bcdata(mm)%norm(i, j, 1) + tauxy*bcdata(mm)%norm(i, j&
&         , 2) + tauxz*bcdata(mm)%norm(i, j, 3)
        fy = tauxy*bcdata(mm)%norm(i, j, 1) + tauyy*bcdata(mm)%norm(i, j&
&         , 2) + tauyz*bcdata(mm)%norm(i, j, 3)
        fz = tauxz*bcdata(mm)%norm(i, j, 1) + tauyz*bcdata(mm)%norm(i, j&
&         , 2) + tauzz*bcdata(mm)%norm(i, j, 3)
        fn = fx*bcdata(mm)%norm(i, j, 1) + fy*bcdata(mm)%norm(i, j, 2) +&
&         fz*bcdata(mm)%norm(i, j, 3)
        fx = fx - fn*bcdata(mm)%norm(i, j, 1)
        fy = fy - fn*bcdata(mm)%norm(i, j, 2)
        fz = fz - fn*bcdata(mm)%norm(i, j, 3)
      end do
    else
! compute the local value of y+. due to the usage
! of pointers there is on offset of -1 in dd2wall..
! if we had no viscous force, set the viscous component to zero
      bcdata(mm)%fv = zero
    end if
! increment the local values array with the values we computed here.
    localvalues(ifp:ifp+2) = localvalues(ifp:ifp+2) + fp
    localvalues(ifv:ifv+2) = localvalues(ifv:ifv+2) + fv
    localvalues(imp:imp+2) = localvalues(imp:imp+2) + mp
    localvalues(imv:imv+2) = localvalues(imv:imv+2) + mv
    localvalues(isepsensor) = localvalues(isepsensor) + sepsensor
    localvalues(icavitation) = localvalues(icavitation) + cavitation
    localvalues(isepavg:isepavg+2) = localvalues(isepavg:isepavg+2) + &
&     sepsensoravg
  end subroutine wallintegrationface
end module surfaceintegrations_b
