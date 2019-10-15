!=========================================================
subroutine rp1(maxmx,meqn,mwaves,maux,mbc,mx,ql,qr,auxl,auxr,wave,s,amdq,apdq)
!=========================================================
!
! Roe-solver for the 1D ideal MHD equations
!
! waves:     7
! equations: 8
!
! Conserved quantities:
!       1 density
!       2 momentum, x
!       3 momentum, y
!       4 momentum, z
!       5 energy
!       6 magnetic field, x
!       7 magnetic field, y
!       8 magnetic field, z
!
! On input, ql contains the state vector at the left edge of each cell
!           qr contains the state vector at the right edge of each cell
!
! On output, wave contains the waves,
!            s the speeds,
!            amdq the  left-going flux difference  A^- \Delta q
!            apdq the right-going flux difference  A^+ \Delta q
!            (where the flux difference is f(qr(i-1)) - f(ql(i)))
!
! With the Roe solver we have
!   amdq  =  A^- \Delta q    and    apdq  =  A^+ \Delta q
! where A is the Roe matrix.
! An entropy fix can also be incorporated into the flux differences.
!
! Note that the i'th Riemann problem has left state qr(i-1,:)
!                                    and right state ql(i,:)
! From the basic clawpack routine step1, rp is called with ql = qr = q.


    implicit double precision (a-h,o-z)

    integer, intent(in) :: maxmx, meqn, mwaves, mbc, mx, maux
    double precision, dimension(meqn, 1-mbc:maxmx+mbc),         intent(in)  :: ql, qr
    double precision, dimension(maux, 1-mbc:maxmx+mbc),         intent(in)  :: auxl, auxr
    double precision, dimension(meqn, mwaves, 1-mbc:maxmx+mbc), intent(out) :: wave
    double precision, dimension(meqn, 1-mbc:maxmx+mbc),         intent(out) :: amdq, apdq
    double precision, dimension(mwaves, 1-mbc:maxmx+mbc),       intent(out) :: s

    double precision, dimension(8)   :: fl, fr, df
    double precision, dimension(4)   :: eigl, eigr
    double precision, dimension(7)   :: stmp
    double precision, dimension(8,7) :: rr
    double precision, dimension(7,8) :: rl
    double precision, dimension(7)   :: alpha, beta

    logical efix

    common /param/ gamma, gamma1

    ! TODO
    ! dimension wave(1-mbc:maxmx+mbc, meqn, mwaves)
    ! dimension    s(1-mbc:maxmx+mbc, mwaves)
    ! dimension   ql(1-mbc:maxmx+mbc, meqn)
    ! dimension   qr(1-mbc:maxmx+mbc, meqn)
    ! dimension  apdq(1-mbc:maxmx+mbc, meqn)
    ! dimension  amdq(1-mbc:maxmx+mbc, meqn)
    ! dimension  auxl(1-mbc:maxmx+mbc, *)
    ! dimension  auxr(1-mbc:maxmx+mbc, *)

    ! use entropy fix for transonic rarefactions
    data efix /.true./

    ixy = 1
    if (ixy == 1) then
        mu1 = 2
        mu2 = 3
        mb1 = 6
        mb2 = 7
    elseif (ixy == 2) then
        mu1 = 3
        mu2 = 2
        mb1 = 7
        mb2 = 6
    endif

    do i = 2-mbc, mx+mbc
        ! Left and Right states
        rhol = qr(1, i-1)
        rhor = ql(1, i  )

        if(rhol <= 1.d-15 .or. rhor <= 1.d-15) then
            print*, ' '
            print*, ' ERROR in RPN:  rhol = ', rhol
            print*, ' ERROR in RPN:  rhor = ', rhor
            print*, ' '
            stop
        endif

        u1l = qr(mu1, i-1) / rhol
        u2l = qr(mu2, i-1) / rhol
        u3l = qr(4,   i-1) / rhol
        El  = qr(5,   i-1)
        B1l = qr(mb1, i-1)
        B2l = qr(mb2, i-1)
        B3l = qr(8,   i-1)
        pl  = gamma1 * (El - 0.5d0 * rhol * (u1l**2 + u2l**2 + u3l**2) - 0.5d0 * (B1l**2 + B2l**2 + B3l**2))

        u1r = ql(mu1, i  ) / rhor
        u2r = ql(mu2, i  ) / rhor
        u3r = ql(4,   i  ) / rhor
        Er  = ql(5,   i  )
        B1r = ql(mb1, i  )
        B2r = ql(mb2, i  )
        B3r = ql(8,   i  )
        pr  = gamma1 * (Er - 0.5d0 * rhor * (u1r**2 + u2r**2 + u3r**2) -0.5d0 * (B1r**2 + B2r**2 + B3r**2))

        !Average states
        rho = 0.5d0 * (rhol + rhor)
        u1  = 0.5d0 * (u1l + u1r)
        u2  = 0.5d0 * (u2l + u2r)
        u3  = 0.5d0 * (u3l + u3r)
        p   = 0.5d0 * (pl + pr)
        B1  = 0.5d0 * (B1l + B1r)
        B2  = 0.5d0 * (B2l + B2r)
        B3  = 0.5d0 * (B3l + B3r)

        ! Delta f
        call set_flux_fun(mu1, mu2, mb1, mb2, rhol, u1l, u2l, u3l, pl, B1l, B2l, B3l, El, fl)
        call set_flux_fun(mu1, mu2, mb1, mb2, rhor, u1r, u2r, u3r, pr, B1r, B2r, B3r, Er, fr)
        do m1 = 1, meqn
            df(m1) = fr(m1) - fl(m1)
        enddo

        ! Wave Speeds
        do mm = 1, 7
            stmp(mm) = 0.d0
        enddo
        call set_wave_spd(rhol, u1l, u2l, u3l, pl, B1l, B2l, B3l, gamma, stmp)
        eigl(1) = stmp(1)
        eigl(2) = stmp(3)
        eigl(3) = stmp(5)
        eigl(4) = stmp(7)
        call set_wave_spd(rhor, u1r, u2r, u3r, pr, B1r, B2r, B3r, gamma, stmp)
        eigr(1) = stmp(1)
        eigr(2) = stmp(3)
        eigr(3) = stmp(5)
        eigr(4) = stmp(7)
        call set_wave_spd(rho, u1, u2, u3, p, B1, B2, B3, gamma, stmp)
        do m1=1,7
          s(i,m1) = stmp(m1)
        enddo

        ! Right Eigenvectors (row,column)
        call set_rght_eig(mu1, mu2, mb1, mb2, rho, u1, u2, u3, p, B1, B2, B3, gamma, rr)

        ! Left Eigenvectors (row,column)
        call set_left_eig(mu1, mu2, mb1, mb2, rho, u1, u2, u3, p, B1, B2, B3, gamma, rl)

        ! Betas and Alphas
        do m1 = 1, mwaves
            beta(m1) = 0.d0
            do m2 = 1, meqn
                beta(m1) = beta(m1) + rl(m1,m2) * df(m2)
            enddo

            if (dabs(s(i,m1)) > 1.d-15) then
                alpha(m1) = beta(m1) / s(i,m1)
            else
                s(m1, i)  = 0.d0
                alpha(m1) = 0.d0
            endif
        enddo

        ! Waves
        do m1 = 1, mwaves
            do m2 = 1, meqn
                wave(m2, m1, i) = alpha(m1) * rr(m2, m1)
            enddo
        enddo


        ! compute left-going and right-going flux differences:
        !------------------------------------------------------
        !
        ! amdq = SUM s*wave   over left-going waves
        ! apdq = SUM s*wave   over right-going waves

        mflag = 0
        if (efix) then
            ! check if entropy fix is needed
            do mm = 1, 4
                if (eigl(mm) * eigr(mm) < 0.d0) then
                    mflag = 1
                endif
            enddo
        endif

        ! Solution update
        if (mflag == 0) then ! # WAVE PROPAGATION METHOD

            do m1 = 1, meqn
                amdq(m1, i) = 0.d0
                apdq(m1, i) = 0.d0

                do m2 = 1, mwaves
                    if (s(i,m2) < -1.d-15) then
                        amdq(m1, i) = amdq(m1, i) + s(m2, i) * wave(m1, m2, i)
                    elseif (s(i,m2) > 1.d-15) then
                        apdq(m1, i) = apdq(m1, i) + s(m2, i) * wave(m1, m2, i)
                    else
                        if (dabs(beta(m2)) > 1.d-15) then
                            print*, ' '
                            print*, ' In RPN: Conservation fix '
                            print*, ' '
                            print*, ' beta(m2) = ', beta(m2)
                            read*
                        endif
                        amdq(i,m1) = amdq(i,m1) + 0.5d0*beta(m2)*rr(m1,m2)
                        apdq(i,m1) = apdq(i,m1) + 0.5d0*beta(m2)*rr(m1,m2)
                    endif
                enddo
            enddo

        else !# HLL ENTROPY FIX

            sl = eigl(1)
            sr = eigr(4)

            do m1 = 1, meqn
                if (dabs(sl-sr) < 1.d-15) then
                    amdq(m1, i) = 0.d0
                    apdq(m1, i) = 0.d0
                else
                    qs = (df(m1) + sl * qr(m1, i-1) - sr * ql(m1, i)) / (sl - sr)

                    amdq(i,m1) = sl * (qs - qr(m1, i-1))
                    apdq(i,m1) = sr * (ql(m1, i) - qs)
                endif

                do m2 = 1, mwaves
                    wave(m1, m2, i) = 0.d0
                enddo
            enddo

        endif

    enddo


    return
end


!=========================================================
subroutine set_flux_fun(mu1, mu2, mb1, mb2, rho, u1, u2, u3, p, B1, B2, B3, E, f)
!=========================================================

    implicit double precision (a-h,o-z)
    double precision, dimension(8), intent(out) :: f

    Bm = 0.5d0 * (B1**2 + B2**2 + B3**2)
    Bu = u1 * B1 + u2 * B2 + u3 * B3

    f(1)   = rho * u1
    f(mu1) = rho * u1**2 + p + Bm - B1**2
    f(mu2) = rho * u1*u2 - B1*B2
    f(4)   = rho * u1*u3 - B1*B3
    f(5)   = u1 * (E + p + Bm) - B1 * Bu
    f(mb1) = 0.d0
    f(mb2) = u1*B2 - u2*B1
    f(8)   = u1*B3 - u3*B1

    return
end


!=========================================================
subroutine set_left_eig(mu1, mu2, mb1, mb2, rho, u1, u2, u3, p, B1, B2, B3, gamma, rl)
!=========================================================

    implicit double precision (a-h,o-z)
    double precision, dimension(7,8), intent(out) :: rl

    a2 = gamma * p / rho
    a = dsqrt(a2)
    d = a2 + (B1**2 + B2**2 + B3**2) / rho

    ca = dsqrt(B1**2 / rho)
    cf = dsqrt(0.5d0 * ( d + dsqrt(d**2 - 4.d0 * a2 * B1 * B1 / rho)))
    cs = dsqrt(0.5d0 * ( d - dsqrt(d**2 - 4.d0 * a2 * B1 * B1 / rho)))

    beta1 = dsign(1.d0, B1)
    if ( (dabs(B2) + dabs(B3)) <= 1.d-15 ) then
        beta2 = 1.d0 / dsqrt(2.d0)
        beta3 = 1.d0 / dsqrt(2.d0)
    else
        beta2 = B2 / dsqrt(B2*B2 + B3*B3)
        beta3 = B3 / dsqrt(B2*B2 + B3*B3)
    endif

    if ( (dabs(B2) + dabs(B3)) <= 1.d-15 .and. dabs(a2 - B1*B1/rho) <=1.d-15 ) then
        alphaf = 1.d0
        alphas = 1.d0
    else
        alphaf = dsqrt(dabs(cf * cf - ca*ca)) / dsqrt(dabs(cf * cf - cs * cs))
        alphas = dsqrt(dabs(cf * cf - a2   )) / dsqrt(dabs(cf * cf - cs * cs))
    endif

    g1 = gamma - 1.d0
    g2 = gamma - 2.d0

    um2 = u1**2 + u2**2 + u3**2
    th1 = alphaf*alphaf*a2*(cf*cf - (g2/g1)*a2) + alphas*alphas*cf*cf*(cs*cs - (g2/g1)*a2)
    th1 = 1.d0 / th1
    th2 = alphaf*alphaf*cf*a*beta1 + alphas*alphas*cs*ca*beta1
    th2 = 1.d0 / th2

    ! 1 - left eigenvector
    rl(1,1)   = th1*(alphaf/4.d0)*a2*um2 + 0.5d0*th2*(alphaf*a*u1*beta1 - alphas*cs*(beta2*u2 + beta3*u3))
    rl(1,mu1) = -0.5d0*th1*alphaf*a2*u1 - 0.5d0*th2*alphaf*a*beta1
    rl(1,mu2) = -0.5d0*th1*alphaf*a2*u2 + 0.5d0*th2*alphas*cs*beta2
    rl(1,4)   = -0.5d0*th1*alphaf*a2*u3 + 0.5d0*th2*alphas*cs*beta3
    rl(1,5)   = 0.5d0*th1*alphaf*a2
    rl(1,mb1) = 0.d0
    rl(1,mb2) = 0.5d0*th1*alphas*beta2*cf*(cs*cs - (g2/g1)*a2)*dsqrt(rho)
    rl(1,8)   = 0.5d0*th1*alphas*beta3*cf*(cs*cs - (g2/g1)*a2)*dsqrt(rho)

    ! 2 - left eigenvector
    rl(2,1)   = -0.5d0*(beta3*u2-beta2*u3)*beta1
    rl(2,mu1) = 0.d0
    rl(2,mu2) = 0.5d0*beta3*beta1
    rl(2,4)   = -0.5d0*beta2*beta1
    rl(2,5)   = 0.d0
    rl(2,mb1) = 0.d0
    rl(2,mb2) = 0.5d0*beta3*dsqrt(rho)
    rl(2,8)   = -0.5d0*beta2*dsqrt(rho)

    ! 3 - left eigenvector
    rl(3,1)   = th1*(alphas/4.d0)*cf*cf*um2 + 0.5d0*th2*(alphas*ca*u1*beta1 + alphaf*cf*(beta2*u2 + beta3*u3))
    rl(3,mu1) = -0.5d0*th1*alphas*cf*cf*u1 - 0.5d0*th2*alphas*ca*beta1
    rl(3,mu2) = -0.5d0*th1*alphas*cf*cf*u2 - 0.5d0*th2*alphaf*cf*beta2
    rl(3,4)   = -0.5d0*th1*alphas*cf*cf*u3 - 0.5d0*th2*alphaf*cf*beta3
    rl(3,5)   = 0.5d0*th1*alphas*cf*cf
    rl(3,mb1) = 0.d0
    rl(3,mb2) = -0.5d0*th1*alphaf*beta2*cf*(cf*cf - (g2/g1)*a2)*dsqrt(rho)
    rl(3,8)   = -0.5d0*th1*alphaf*beta3*cf*(cf*cf - (g2/g1)*a2)*dsqrt(rho)

    ! 4 - left eigenvector
    rl(4,1)   = 1.d0 - 0.5d0*th1*(alphaf*alphaf*a2 + alphas*alphas*cf*cf)*um2
    rl(4,mu1) = th1*(alphaf*alphaf*a2 + alphas*alphas*cf*cf)*u1
    rl(4,mu2) = th1*(alphaf*alphaf*a2 + alphas*alphas*cf*cf)*u2
    rl(4,4)   = th1*(alphaf*alphaf*a2 + alphas*alphas*cf*cf)*u3
    rl(4,5)   = -th1*(alphaf*alphaf*a2 + alphas*alphas*cf*cf)
    rl(4,mb1) = 0.d0
    rl(4,mb2) = th1*alphaf*alphas*beta2*cf*(cf*cf-cs*cs)*dsqrt(rho)
    rl(4,8)   = th1*alphaf*alphas*beta3*cf*(cf*cf-cs*cs)*dsqrt(rho)

    ! 5 - left eigenvector
    rl(5,1)   = th1*(alphas/4.d0)*cf*cf*um2 - 0.5d0*th2*(alphas*ca*u1*beta1 + alphaf*cf*(beta2*u2 + beta3*u3))
    rl(5,mu1) = -0.5d0*th1*alphas*cf*cf*u1 + 0.5d0*th2*alphas*ca*beta1
    rl(5,mu2) = -0.5d0*th1*alphas*cf*cf*u2 + 0.5d0*th2*alphaf*cf*beta2
    rl(5,4)   = -0.5d0*th1*alphas*cf*cf*u3 + 0.5d0*th2*alphaf*cf*beta3
    rl(5,5)   = 0.5d0*th1*alphas*cf*cf
    rl(5,mb1) = 0.d0
    rl(5,mb2) = -0.5d0*th1*alphaf*beta2*cf*(cf*cf - (g2/g1)*a2)*dsqrt(rho)
    rl(5,8)   = -0.5d0*th1*alphaf*beta3*cf*(cf*cf - (g2/g1)*a2)*dsqrt(rho)

    ! 6 - left eigenvector
    rl(6,1)   = 0.5d0*(beta3*u2-beta2*u3)*beta1
    rl(6,mu1) = 0.d0
    rl(6,mu2) = -0.5d0*beta3*beta1
    rl(6,4)   = 0.5d0*beta2*beta1
    rl(6,5)   = 0.d0
    rl(6,mb1) = 0.d0
    rl(6,mb2) = 0.5d0*beta3*dsqrt(rho)
    rl(6,8)   = -0.5d0*beta2*dsqrt(rho)

    ! 7 - left eigenvector
    rl(7,1)   = th1*(alphaf/4.d0)*a2*um2 - 0.5d0*th2*(alphaf*a*u1*beta1 - alphas*cs*(beta2*u2 + beta3*u3))
    rl(7,mu1) = -0.5d0*th1*alphaf*a2*u1 + 0.5d0*th2*alphaf*a*beta1
    rl(7,mu2) = -0.5d0*th1*alphaf*a2*u2 - 0.5d0*th2*alphas*cs*beta2
    rl(7,4)   = -0.5d0*th1*alphaf*a2*u3 - 0.5d0*th2*alphas*cs*beta3
    rl(7,5)   = 0.5d0*th1*alphaf*a2
    rl(7,mb1) = 0.d0
    rl(7,mb2) = 0.5d0*th1*alphas*beta2*cf*(cs*cs - (g2/g1)*a2)*dsqrt(rho)
    rl(7,8)   = 0.5d0*th1*alphas*beta3*cf*(cs*cs - (g2/g1)*a2)*dsqrt(rho)

    return
end


!=========================================================
subroutine set_rght_eig(mu1, mu2, mb1, mb2, rho, u1, u2, u3, p, B1, B2, B3, gamma, rr)
!=========================================================

    implicit double precision (a-h,o-z)
    double precision, dimension(8,7), intent(out) :: rr

    a2 = gamma * p / rho
    a = dsqrt(a2)
    d = a2 + (B1**2 + B2**2 + B3**2) / rho

    ca = dsqrt(B1**2 / rho)
    cf = dsqrt(0.5d0 * ( d + dsqrt(d**2 - 4.d0*a2*B1*B1/rho)))
    cs = dsqrt(0.5d0 * ( d - dsqrt(d**2 - 4.d0*a2*B1*B1/rho)))

    beta1 = dsign(1.d0,B1)
    if ( (dabs(B2) + dabs(B3)) <= 1.d-15 ) then
        beta2 = 1.d0 / dsqrt(2.d0)
        beta3 = 1.d0 / dsqrt(2.d0)
    else
        beta2 = B2 / dsqrt(B2*B2 + B3*B3)
        beta3 = B3 / dsqrt(B2*B2 + B3*B3)
    endif

    if ( (dabs(B2) + dabs(B3)) <= 1.d-15 .and. dabs(a2 - B1*B1/rho) < 1.d-15 ) then
        alphaf = 1.d0
        alphas = 1.d0
    else
        alphaf = dsqrt(dabs(cf*cf - ca*ca))/dsqrt(dabs(cf*cf-cs*cs))
        alphas = dsqrt(dabs(cf*cf - a2))/dsqrt(dabs(cf*cf-cs*cs))
    endif

    g1 = gamma - 1.d0
    g2 = gamma - 2.d0
    hmf = (alphaf*cf*cf/g1) - alphaf*cf*u1 + alphas*ca*beta1*(beta2*u2 + beta3*u3) + (g2/g1)*alphaf*(cf*cf-a2)
    hpf = (alphaf*cf*cf/g1) + alphaf*cf*u1 - alphas*ca*beta1*(beta2*u2 + beta3*u3) + (g2/g1)*alphaf*(cf*cf-a2)
    hms = (alphas*cs*cs/g1) - alphas*cs*u1 - alphaf*a*beta1*(beta2*u2 + beta3*u3) + (g2/g1)*alphas*(cs*cs-a2)
    hps = (alphas*cs*cs/g1) + alphas*cs*u1 + alphaf*a*beta1*(beta2*u2 + beta3*u3) + (g2/g1)*alphas*(cs*cs-a2)

    ! 1 - right eigenvector
    rr(1,1)   = alphaf
    rr(mu1,1) = alphaf*(u1-cf)
    rr(mu2,1) = alphaf*u2 + alphas*beta2*ca*beta1
    rr(4,1)   = alphaf*u3 + alphas*beta3*ca*beta1
    rr(5,1)   = 0.5d0*alphaf*(u1**2 + u2**2 + u3**2) + hmf
    rr(mb1,1) = 0.d0
    rr(mb2,1) = alphas*beta2*cf/dsqrt(rho)
    rr(8,1)   = alphas*beta3*cf/dsqrt(rho)

    ! 2 - right eigenvector
    rr(1,2)   = 0.d0
    rr(mu1,2) = 0.d0
    rr(mu2,2) = beta3*beta1
    rr(4,2)   = -beta2*beta1
    rr(5,2)   = (beta3*u2 - beta2*u3)*beta1
    rr(mb1,2) = 0.d0
    rr(mb2,2) = beta3/dsqrt(rho)
    rr(8,2)   = -beta2/dsqrt(rho)

    ! 3 - right eigenvector
    rr(1,3)   = alphas
    rr(mu1,3) = alphas*(u1-cs)
    rr(mu2,3) = alphas*u2 - alphaf*beta2*a*beta1
    rr(4,3)   = alphas*u3 - alphaf*beta3*a*beta1
    rr(5,3)   = 0.5d0*alphas*(u1**2 + u2**2 + u3**2) + hms
    rr(mb1,3) = 0.d0
    rr(mb2,3) = -alphaf*beta2*a2/(cf*dsqrt(rho))
    rr(8,3)   = -alphaf*beta3*a2/(cf*dsqrt(rho))

    ! 4 - right eigenvector
    rr(1,4)   = 1.d0
    rr(mu1,4) = u1
    rr(mu2,4) = u2
    rr(4,4)   = u3
    rr(5,4)   = 0.5d0*(u1**2 + u2**2 + u3**2)
    rr(mb1,4) = 0.d0
    rr(mb2,4) = 0.d0
    rr(8,4)   = 0.d0

    ! 5 - right eigenvector
    rr(1,5)   = alphas
    rr(mu1,5) = alphas*(u1+cs)
    rr(mu2,5) = alphas*u2 + alphaf*beta2*a*beta1
    rr(4,5)   = alphas*u3 + alphaf*beta3*a*beta1
    rr(5,5)   = 0.5d0*alphas*(u1**2 + u2**2 + u3**2) + hps
    rr(mb1,5) = 0.d0
    rr(mb2,5) = -alphaf*beta2*a2/(cf*dsqrt(rho))
    rr(8,5)   = -alphaf*beta3*a2/(cf*dsqrt(rho))

    ! 6 - right eigenvector
    rr(1,6)   = 0.d0
    rr(mu1,6) = 0.d0
    rr(mu2,6) = -beta3*beta1
    rr(4,6)   = beta2*beta1
    rr(5,6)   = -(beta3*u2 - beta2*u3)*beta1
    rr(mb1,6) = 0.d0
    rr(mb2,6) = beta3/dsqrt(rho)
    rr(8,6)   = -beta2/dsqrt(rho)

    ! 7 - right eigenvector
    rr(1,7)   = alphaf
    rr(mu1,7) = alphaf*(u1+cf)
    rr(mu2,7) = alphaf*u2 - alphas*beta2*ca*beta1
    rr(4,7)   = alphaf*u3 - alphas*beta3*ca*beta1
    rr(5,7)   = 0.5d0*alphaf*(u1**2 + u2**2 + u3**2) + hpf
    rr(mb1,7) = 0.d0
    rr(mb2,7) = alphas*beta2*cf/dsqrt(rho)
    rr(8,7)   = alphas*beta3*cf/dsqrt(rho)

    return
end


!=========================================================
subroutine set_wave_spd(rho,u1,u2,u3,p,B1,B2,B3,gamma,s)
!=========================================================

    implicit double precision (a-h,o-z)
    double precision, dimension(7), intent(out) :: s

    a2 = gamma * p / rho
    d = a2 + (B1**2 + B2**2 + B3**2) / rho

    ca = dsqrt(B1**2/rho)
    cf = dsqrt(0.5d0 * ( d + dsqrt(d**2 - 4.d0*a2*B1*B1/rho)))
    cs = dsqrt(0.5d0 * ( d - dsqrt(d**2 - 4.d0*a2*B1*B1/rho)))

    s(1) = u1 - cf
    s(2) = u1 - ca
    s(3) = u1 - cs
    s(4) = u1
    s(5) = u1 + cs
    s(6) = u1 + ca
    s(7) = u1 + cf

    return
end
