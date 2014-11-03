   !        Generated by TAPENADE     (INRIA, Tropics team)
   !  Tapenade 3.10 (r5363) -  9 Sep 2014 09:53
   !
   !  Differentiation of setssbwd in reverse (adjoint) mode (with options i4 dr8 r8 noISIZE):
   !   gradient     of useful results: *si *sj *sk ssi ssj ssk
   !   with respect to varying inputs: *si *sj *sk ssi ssj ssk
   !   Plus diff mem management of: si:in sj:in sk:in
   !
   !      ******************************************************************
   !      *                                                                *
   !      * File:          setssBwd.f90                                    *
   !      * Author:        Peter Zhoujie Lyu                               *
   !      * Starting date: 10-21-2014                                      *
   !      * Last modified: 10-21-2014                                      *
   !      *                                                                *
   !      ******************************************************************
   SUBROUTINE SETSSBWD_B(nn, ssi, ssib, ssj, ssjb, ssk, sskb, ss)
   USE BCTYPES
   USE BLOCKPOINTERS_B
   USE FLOWVARREFSTATE
   IMPLICIT NONE
   !
   !      Subroutine arguments.
   !
   INTEGER(kind=inttype), INTENT(IN) :: nn
   REAL(kind=realtype), DIMENSION(imaxdim, jmaxdim, 3) :: ssi, ssj, ssk
   REAL(kind=realtype), DIMENSION(imaxdim, jmaxdim, 3) :: ssib, ssjb, &
   & sskb
   REAL(kind=realtype), DIMENSION(imaxdim, jmaxdim, 3) :: ss
   !
   !      ******************************************************************
   !      *                                                                *
   !      * Begin execution                                                *
   !      *                                                                *
   !      ******************************************************************
   !
   ! Determine the face id on which the subface is located and set
   ! the pointers accordinly.
   SELECT CASE  (bcfaceid(nn)) 
   CASE (imin) 
   skb(2, 1:je, 0:ke, :) = skb(2, 1:je, 0:ke, :) + sskb(1:je, 0:ke, :)
   sskb(1:je, 0:ke, :) = 0.0_8
   sjb(2, 0:je, 1:ke, :) = sjb(2, 0:je, 1:ke, :) + ssjb(0:je, 1:ke, :)
   ssjb(0:je, 1:ke, :) = 0.0_8
   sib(1, 1:je, 1:ke, :) = sib(1, 1:je, 1:ke, :) + ssib(1:je, 1:ke, :)
   ssib(1:je, 1:ke, :) = 0.0_8
   CASE (imax) 
   skb(il, 1:je, 0:ke, :) = skb(il, 1:je, 0:ke, :) + sskb(1:je, 0:ke, :&
   &     )
   sskb(1:je, 0:ke, :) = 0.0_8
   sjb(il, 0:je, 1:ke, :) = sjb(il, 0:je, 1:ke, :) + ssjb(0:je, 1:ke, :&
   &     )
   ssjb(0:je, 1:ke, :) = 0.0_8
   sib(il, 1:je, 1:ke, :) = sib(il, 1:je, 1:ke, :) + ssib(1:je, 1:ke, :&
   &     )
   ssib(1:je, 1:ke, :) = 0.0_8
   CASE (jmin) 
   skb(1:ie, 2, 0:ke, :) = skb(1:ie, 2, 0:ke, :) + sskb(1:ie, 0:ke, :)
   sskb(1:ie, 0:ke, :) = 0.0_8
   sib(1:ie, 2, 1:ke, :) = sib(1:ie, 2, 1:ke, :) + ssjb(1:ie, 1:ke, :)
   ssjb(1:ie, 1:ke, :) = 0.0_8
   sjb(0:ie, 1, 1:ke, :) = sjb(0:ie, 1, 1:ke, :) + ssib(0:ie, 1:ke, :)
   ssib(0:ie, 1:ke, :) = 0.0_8
   CASE (jmax) 
   skb(1:ie, jl, 0:ke, :) = skb(1:ie, jl, 0:ke, :) + sskb(1:ie, 0:ke, :&
   &     )
   sskb(1:ie, 0:ke, :) = 0.0_8
   sib(1:ie, jl, 1:ke, :) = sib(1:ie, jl, 1:ke, :) + ssjb(1:ie, 1:ke, :&
   &     )
   ssjb(1:ie, 1:ke, :) = 0.0_8
   sjb(0:ie, jl, 1:ke, :) = sjb(0:ie, jl, 1:ke, :) + ssib(0:ie, 1:ke, :&
   &     )
   ssib(0:ie, 1:ke, :) = 0.0_8
   CASE (kmin) 
   sjb(1:ie, 1:je, 2, :) = sjb(1:ie, 1:je, 2, :) + sskb(1:ie, 1:je, :)
   sskb(1:ie, 1:je, :) = 0.0_8
   sib(1:ie, 0:je, 2, :) = sib(1:ie, 0:je, 2, :) + ssjb(1:ie, 0:je, :)
   ssjb(1:ie, 0:je, :) = 0.0_8
   skb(0:ie, 1:je, 1, :) = skb(0:ie, 1:je, 1, :) + ssib(0:ie, 1:je, :)
   ssib(0:ie, 1:je, :) = 0.0_8
   CASE (kmax) 
   sjb(1:ie, 1:je, kl, :) = sjb(1:ie, 1:je, kl, :) + sskb(1:ie, 1:je, :&
   &     )
   sskb(1:ie, 1:je, :) = 0.0_8
   sib(1:ie, 0:je, kl, :) = sib(1:ie, 0:je, kl, :) + ssjb(1:ie, 0:je, :&
   &     )
   ssjb(1:ie, 0:je, :) = 0.0_8
   skb(0:ie, 1:je, kl, :) = skb(0:ie, 1:je, kl, :) + ssib(0:ie, 1:je, :&
   &     )
   ssib(0:ie, 1:je, :) = 0.0_8
   END SELECT
   END SUBROUTINE SETSSBWD_B
