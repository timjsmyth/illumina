c                         *                          *                       iii                   *     *
c                                                                           iiiii
c  IIIIII    lLLLL    *    lLLLL         UUU    UUU      MMMMM      MMMMM    iii        NNNN     NN          AAAA
c   IIII     LLLL          LLLL   *     UUU      UUU     MMMMMMM  MMMMMMM          *    NNNNN    NN        AAAaaAAA
c   IIII     LLLL          LLLL        UUU *      UUU    MMM MMMMMMMM MMM    iii        NNNNNN   NN       AAA    AAA
c   IIII     LLLL   *      LLLL        UUU        UUU    MMM *        MMM  iii          NNN  NNN NN     AAAAAAAAAAAAAA
c   IIII     LLLl          LLLl        UUUu      uUUU    MMM          MMM  iiii    ii   NNN   NNNNN    AAAa        aAAA
c   IIII    LLLLLLLLLL    LLLLLLLLLL    UUUUUuuUUUUU     MMM          MMM   iiiiiiiii   NNN    NNNN   aAAA    *     AAAa
c  IIIIII   LLLLLLLLLLL   LLLLLLLLLLL     UUUUUUUU      mMMMm        mMMMm   iiiiiii   nNNNn    NNNn  aAAA          AAAa
c
c **********************************************************************************************************************
c ** Illumina en Fortran 77                                                                                           **
c ** Programmers in decreasing order of contribution  :                                                               **
c **                            Martin Aube, Loic Franchomme-Fosse,  Mathieu Provencher, Andre Morin                  **
c **                            Alex Neron, Etienne Rousseau                                                          ** 
c **                            William Desroches, Maxime Girardin, Tom Neron                                         **
c **                                                                                                                  **
c ** Illumina can be downloaded via:   hg clone  https://aubema@bitbucket.org/aubema/illumina                         **
c ** To compile:                                                                                                      **
c **    cd hg/illumina                                                                                                **
c **    mkdir bin                                                                                                     **
c **    bash makeILLUMINA                                                                                             **
c **                                                                                                                  **
c **  Current version features/limitations :                                                                          **
c **                                                                                                                  **
c **    - Calculation of flux entering a spectrometer in a given line of sight                                        **
c **    - Calculation of the sky spectral luminance in a given line of sight                                          **
c **    - Calculation of the atmospheric transmittance and 1st and 2nd order of scattering                            **
c **    - Lambertian reflexion on the ground                                                                          **
c **    - Terrain slope considered (apparent surface and shadows)                                                     **
c **    - Angular photometry of a lamp is considered uniform along the azimuth                                        **
c **    - Sub-grid obstacles considered (with the mean free path of light toward ground and mean obstacle height      **
c **    - Molecules and aerosol optics (phase function, scattering probability, aerosol absorption)                   **  
c **    - Exponential concentrations vertical profile (H aerosol= 2km, H molecules= 8km  )                            **
c **    - Exponential vertical resolution (max height= 30 km)                                                         **
c **    - Accounting for heterogeneity of ground reflectance, luminaires number, luminaires heights,                  **
c **      angular photometry                                                                                          **
c **    - Wavelength dependant                                                                                        **
c **    - Clouds models                                                                                               **
c **    - Ignore the flux scattered by the voxel occupied by the observer (cellobs=cellcible)                         **
c **    - Do not support direct observation of a source                                                               ** 
c **    - Direct observation of the ground not implemented                                                            **
c **    - Not accounting for molecular absorption                                                                     **
c **    - Do not consider earth curvature (i.e. local/regional model)                                                 **
c **    - No clouds                                                                                                   **
c **                                                                                                                  **
c ** Theoretical equations by Martin Aube, CEGEP of Sherbrooke (in french)                                            **
c **      http://cegepsherbrooke.qc.ca/~aubema/index.php/Prof/IllumEn?action=download&upname=intensity_lumineuse.pdf  **
c **                                                                                                                  **
c **********************************************************************************************************************
c   
c    Copyright (C) 2012 Martin Aube
c
c    This program is free software: you can redistribute it and/or modify
c    it under the terms of the GNU General Public License as published by
c    the Free Software Foundation, either version 3 of the License, or
c    (at your option) any later version.
c
c    This program is distributed in the hope that it will be useful,
c    but WITHOUT ANY WARRANTY; without even the implied warranty of
c    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
c    GNU General Public License for more details.
c
c    You should have received a copy of the GNU General Public License
c    along with this program.  If not, see <http://www.gnu.org/licenses/>.
c
c    Contact: martin.aube@cegepsherbrooke.qc.ca
c
c
c2345678901234567890123456789012345678901234567890123456789012345678901234
c
      program illumina                                                    ! Beginning
c
c=======================================================================
c     Variables declaration
c=======================================================================
c
      integer width,height                                                ! Matrix dimension in Length/width and height
      parameter (width=1024,height=50)
      integer iun,ideux
      real pi,pix4
      integer verbose                                                     ! verbose = 1 to have more print out, 0 for silent
      parameter (pi=3.1415926)
      parameter (pix4=4.*pi)
      real cthick(50)                                                     ! Cell thickness array (meter)
      real cellh(50)                                                      ! Cell height array (meter)
      real flcumu                                                         ! Accrued flux along the line of sight
      character*72 mnaf                                                   ! Terrain elevation file.
      character*72 reflf                                                  ! Reflectance file.
      character*72 diffil                                                 ! Aerosol file.
      character*72 outfile                                                ! Results file
      character*72 pclf,pcwf,pclgp,pcwgp                                  ! File containing contribution and sensitivity maps
      character*72 pclimg,pcwimg                                                                         
      character*72 basenm                                                 ! Base name of files.
      character*12 nom                                                    
      integer lenbase                                                     ! Length of the Base name of the experiment.
      real lambda,pressi,drefle(width,width)                              ! Wavelength (nanometer), atmospheric pressure (kPa), mean free path to the ground (meter).
      integer ntype                                                       ! Number of light source types or zones considered.
      real largx                                                          ! Width (x axis) of the modeling domain (meter).
      real largy                                                          ! Length (y axis) of the modeling domain (meter).
      integer nbx,nby                                                     ! Number of pixels in the modeling domain.  
      real val2d(width,width)                                             ! Temporary input array 2d
      real altsol(width,width)                                            ! Ground elevation (meter).
      real srefl(width,width)                                             ! Ground reflectance.
      real Hmin                                                           ! Minimum ground elevation of the modeling domain
      real xcell0                                                         ! Longitude of the south-west pixel of the domain.
      real ycell0                                                         ! latitude of the south-west pixel of the domain.
      real gain                                                           ! Gain to retreive the physical value from an ADU in pgm file.
      real offset                                                         ! Offset to retreive the physical value from an ADU in pgm file.
      integer valmax                                                      ! Maximum value of the output pgm (usually 65535, i.e. 16 bit)
      integer stype                                                       ! Source type or zone index
      character*72 pafile,lufile,alfile,ohfile,odfile                     ! Files related to light sources and obstacles (photometric function of the sources (sr-1), flux (W), height (m), obstacle height (m), obstacle distance (m).    
      real lamplu(width,width,120)                                        ! Source fluxes
      real lampal(width,width,120)                                        ! Height of the light sources relative to the ground (meter).
      real pval(181,120),pvalto,pvalno(181,120)                           ! Values of the angular photometry functions (unnormalized, integral, normalized).
      real dtheta                                                         ! Angle increment of the photometric function of the sources 
      real dx,dy,dxp,dyp,pixsiz                                           ! Width of the cell (meter)
      integer boxx,boxy                                                   ! reflection window size (pixels).
      real fdifa(181),fdifan(181)                                         ! Aerosol scattering functions (unnormalized and normalized).
      real extinc,scatte,anglea(181)                                      ! Aerosol cross sections (extinction and scattering), scattering angle (degree).
      real secdif                                                         ! Contribution of the scattering to the extinction
      real inclix(width,width)                                            ! tilt of the ground pixel along x (radian).
      real incliy(width,width)                                            ! tilt of the ground pixel along y (radian).   
      integer x_obs,y_obs,zcello                                          ! Position of the observer (INTEGER).
      real z_obs                                                          ! Height of the observer (meter).
      integer lcible(width,3)                                             ! Array for the target voxels along the line of sight.
      integer ncible,icible                                               ! Number of target voxels, number loops over the voxels 
      integer x_c,y_c,zcellc                                              ! Position of the target voxel (INTEGER).
      real z_c                                                            ! Height of the target cell (metre).
      real zcup,zcdown                                                    ! Lower and upper limits of the target voxel.    
      integer dirck                                                       ! Test for the position of the source (case source=target voxel).     
      integer x_s,y_s,x_sr,y_sr,x_dif,y_dif,zceldi                        ! Positions of the source, the reflecting surface, and the scattering voxels 
      real z_s,z_sr,z_dif                                                 ! Heights of the source, the reflecting surface, and the scattering cell (metre).
      real angzen,ouvang                                                  ! Zenithal angle between two cells (radians) and opening angle of the solid angle in degrees.
      integer anglez                                                      ! Emitting zenithal angle from the luminaire.      
      real P_dir,P_indir,P_dif1                                           ! photometric function of the light sources (direct,indirect,scattered) 
      real transa,transm                                                  ! Transmittance between two cells (aerosols,molecules).
      real tran1a,tran1m                                                  ! Transmittance of the cell (aerosols,molecules).
      real taua                                                           ! Aerosol optical depth @ 500nm.
      real alpha                                                          ! Angstrom coefficient of aerosol AOD
      real*8 xc,yc,zc,xn,yn,zn                                            ! Position (meter) of the elements (starting point, final point) for the calculation of the solid angle.  
      real*8 r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z              ! Components of the vectors used in the solid angle calculation routine.
      real omega,omega1                                                   ! Solid angles
      real fldir                                                          ! Flux coming from a source (watt).
      real flindi                                                         ! Flux coming from a reflecting ground element (watt).
      real fldiff                                                         ! Flux coming from a scattering voxel (watt).
      real zidif,zfdif                                                    ! initial and final limits of a scattering path.
      real angdif                                                         ! scattering angle.
      real pdifdi,pdifin,pdifd1,pdifd2                                    ! scattering probability (direct,indirect,1st and 2nd order of scattering 
      real intdir                                                         ! Direct intensity toward the sensor from a scattering voxel.
      real intind                                                         ! Contribution of the reflecting cell to the indirect intensity toward the sensor.
      real itotind                                                        ! Total contribution of the source to the indirect intensity toward the sensor.
      real idiff2                                                         ! Contribution of the scattering cell to the scattered intensity toward the sensor.
      real itodif                                                         ! Total contribution of the source to the scattered intensity toward the sensor.
      real isourc                                                         ! Total contribution of the source to the intensity from a target voxel toward the sensor.
      real itotty                                                         ! Total contribution of a source type to the intensity coming from a target voxel toward the sensor.
      real itotci                                                         ! total intensity from a target voxel toward the sensor.
      real itotrd                                                         ! total intensity a voxel toward the sensor after reflexion and double scattering.
      real irefdi                                                         ! intensity from a voxel toward the sensor after reflexion and double scattering. 
      real flcib                                                          ! Flux reaching the observer voxel from a target cell.
      real fcapt                                                          ! Flux reaching the observer voxel from all FOV voxels in a given model level
      real ftocap                                                         ! Total flux reaching the observer voxel
      real haut                                                           ! Haut (negative indicate that the surface is lighted from inside the ground. I.e. not considered in the calculation
      real epsilx,epsily                                                  ! tilt of the ground pixel
      real flrefl                                                         ! flux reaching a reflecting surface (watts).
      real irefl,irefl1                                                   ! intensity leaving a reflecting surface toward the target voxel.  
      real effdif                                                         ! Distance around the source voxel and target voxel considered to compute the 2nd order of scattering.
      integer zondif(3000000,4)                                           ! Array for the scattering voxels, the 4th column represents the nearest integer value of the distance (en metre) to the line of single scattering.
      integer ndiff,idi                                                   ! Number of scattering voxels, counter of the loop over the scattering voxels
      integer stepdi                                                      ! scattering step to speedup the calculation e.g. if =2 one computation over two will be done
      integer nvis0                                                       ! starting value for the calculation along of the viewing line. 
c                                                                         ! by default the value is 1 but it can be larger  
c                                                                         ! when we resume a previous interrupted calculation.
      real fldif1                                                         ! flux reaching a scattering voxel.
      real idif1                                                          ! intensity toward a target voxel from a scattering cell.
      real portio                                                         ! ratio of voxel surface to the solid angle of the sensor field of view.
      real dis_obs                                                        ! Distance between the target and the observer.
      real ometif                                                         ! Solid angle of the telescope objective as seen from the target voxel
      real omefov                                                         ! Solid angle of the spectrometer slit.
      real lfente                                                         ! Width of the slit (or of the sensor area)
      real longfe                                                         ! Length of the slit (or of the sensor area)
      real focal                                                          ! Focal distance of the spectrometer objective  
      real angvis,azim                                                    ! viewing angles of the sensor.
      real projap                                                         ! Fraction of the reflecting surface relatively to the normal. 
c                                                                         ! Useful for the calculation of the lambertian reflectance.
      real nbang                                                          ! for the averaging of the photometric function
      real obsH(width,width),angmin                                       ! averaged height of the sub-grid obstacles, minimum angle under wich 
c                                                                         ! a light ray cannot propagate because it is blocked by a sub-grid obstable
      integer naz,na 
      real ITT(width,width,120)                                           ! total intensity per type of lamp
      real ITC(width,width)                                               ! total intensity per target voxel
      real FC(width,width)                                                ! target flux
      real FTC(width,width)                                               ! fraction of the total flux at the sensor level 
      real FTCN(width,width)                                              ! fraction of the total flux at the sensor level normalized per unit of watt
      real FCA(width,width)                                               ! sensor flux array
      real lpluto(width,width)                                            ! total luminosity of the ground cell for all lamps
      real fctnto,ftcmax                                                  ! FTCN total for all the domain for all lamps
      character*3 lampno                                                  ! lamp number string
      integer imin(120),imax(120),jmin(120),jmax(120),step(120)           ! x and y limits of the zone containing a type of lamp
      real defval                                                         ! ignored value during interpolation
      real dat(1024,1024)                                                 ! array to be interpolated
      integer autom,intype,ii,jj                                          ! switch manual/automatic for the interpolation; interpolation type
      real window                                                         ! interpolation diameter
      real zhoriz(360)                                                    ! horizon in rad over 360 deg, the first index of the array is for 0 deg while index 360 = 359 deg
      real angazi,d2                                                      ! azimuth angle between two points in rad, max dist for the horizon determination
      integer az                                                          ! azimut of the horizon
      real latitu                                                         ! approximate latitude of the domain center
      integer vistep                                                      ! line of sight step for low elevation angles vistep=ncells_along_sight/50
      integer prmaps                                                      ! flag to enable the tracking of contribution and sensitivity maps
      integer cloudt                                                      ! cloud type 0=clear, 1=Thin Cirrus/Cirrostratus, 2=Thick Cirrus/Cirrostratus, 3=Altostratus/Altocumulus, 4=Cumulus/Cumulonimbus, 5=Stratocumulus
      integer cloudh(5),cloudz                                            ! cloud base layer relative to the lower elevation 
      real rcloud                                                         ! cloud relfectance 
      real azencl                                                         ! zenith angle from cloud to observer
      real icloud                                                         ! cloud reflected intensity
      real fcloud                                                         ! flux reaching the intrument from the cloud cell
      real fccld                                                          ! correction for the FOV to the flux reaching the intrument from the cloud cell
      real fctcld                                                         ! total flux from cloud at the sensor level
      real dsco                                                           ! distancesource-target-observer
      real dminlp                                                         ! minimum distance between the observer and a lamp (m)
      real totlu(120)                                                     ! total flux of a source type
      real stoplim                                                        ! Stop computation when the new voxel contribution is less than 1/stoplim of the cumulated flux
      real zero
      real angaz
      data cthick /0.5,0.6,0.72,0.86,1.04,1.26,1.52,1.84,2.22,            ! thickness of the levels.
     a 2.68,3.24,3.92,4.74,5.72,6.9,8.34,10.08,12.18,14.72,17.78,21.48,
     b 25.94,31.34,37.86,45.74,55.26,66.76,80.64,97.42,117.68,142.16,
     c 171.72,207.44,250.58,302.7,365.66,441.72,533.6,644.58,778.66,
     d 940.62,1136.26,1372.6,1658.1,2002.98,2419.6,2922.88,3530.84,
     e 4265.26,5152.44/
      data cellh /0.25,0.8,1.46,2.25,3.2,4.35,5.74,7.42,9.45,             ! Height of the center of each vertical level.
     a 11.9,14.86,18.44,22.77,28.,34.31,41.93,51.14,62.27,75.72,91.97,
     b 111.6,135.31,163.95,198.55,240.35,290.85,351.86,425.56,514.59,
     c 622.14,752.06,909.,1098.58,1327.59,1604.23,1938.41,2342.1,
     d 2829.76,3418.85,4130.47,4990.11,6028.55,7282.98,8798.33,
     e 10628.87,12840.16,15511.4,18738.26,22636.31,27345.16/
      data cloudh /44,44,40,33,33/                                        ! 9300.,9300.,4000.,1200.,1100.
      verbose=0
      zero=0.
c  
c=======================================================================
c        reading of the fichier d'entree (illumina.in)
c=======================================================================
      open(unit=1,file='illumina.in',status='old')
       read(1,*)
       read(1,*) basenm
       read(1,*) 
       read(1,*) dx,dy
       read(1,*)
       read(1,*) diffil
       read(1,*) 
       read(1,*) effdif,stepdi
       if (verbose.eq.1) then
         print*,'2nd order scattering radius=',effdif,'m   1 voxel over
     a    ',stepdi
       endif
       read(1,*)
       read(1,*) lambda
       read(1,*) pressi
       read(1,*) taua,alpha
       read(1,*) ntype
       read(1,*) stoplim
       read(1,*)
       read(1,*) x_obs,y_obs,zcello,nvis0
       read(1,*)
       read(1,*) angvis,azim
       read(1,*) 
       read(1,*) lfente,longfe,focal,diamobj 
       read(1,*)
       read(1,*)
       read(1,*) cloudt  
       read(1,*) dminlp 

         print*,'Minimum distance to the source=',dminlp

      close(1)
c
c computing the actual AOD at the wavelength lambda
c      
       taua=taua*(lambda/500.)**(-1.*alpha)
c
c  determine the Length of basenm
c 
      lenbase=index(basenm,' ')-1  
      mnaf=basenm(1:lenbase)//'_topogra.pgm'                              ! determine the names of input and output files
      reflf=basenm(1:lenbase)//'_reflect.pgm' 
      outfile=basenm(1:lenbase)//'.out'  
      pclf=basenm(1:lenbase)//'_pcl.txt'
      pcwf=basenm(1:lenbase)//'_pcw.txt'
      pclimg=basenm(1:lenbase)//'_pcl.pgm'
      pcwimg=basenm(1:lenbase)//'_pcw.pgm'
      pclgp=basenm(1:lenbase)//'_pcl.gplot'
      pcwgp=basenm(1:lenbase)//'_pcw.gplot'    
c  conversion of the geographical viewing angles toward the cartesian 
c  angle we assume that the angle in the file illumina.in
c  is consistent with the geographical definition 
c  geographical, azim=0 toward north, 90 toward east, 180 toward south 
c  etc
c  cartesian, azim=0 toward east, 90 toward north, 180 toward west etc
      azim=90.-azim
      if (azim.lt.0.) azim=azim+360.
      if (azim.ge.360.) azim=azim-360.
c  opening output file
      open(unit=2,file=outfile,status='unknown')      
       write(2,*) 'FILE USED:'
       write(2,*) mnaf,reflf,diffil
       print*,'Wavelength (nm):',lambda,
     +       ' Aerosol optical depth:',taua
       write(2,*) 'Wavelength (nm):',lambda,
     +       ' Aerosol optical depth:',taua
       write(2,*) '2nd order scattering radius:',effdif,' m'
       print*,'2nd order scattering radius:',effdif,' m'
       write(2,*) 'Scattering step:',stepdi
       print*,'Scattering step:',stepdi

       write(2,*) 'Observer position (x,y,z)',x_obs,y_obs,zcello
       print*,'Observer position (x,y,z)',x_obs,y_obs,zcello
       write(2,*) 'Elevation angle:',angvis,' azim angle (clockwise fro
     + m north)',azim     
       print*,'Elevation angle:',angvis,' azim angle (counterclockwise f
     + rom east)',azim 
c=======================================================================
c        Initialisation of the arrays and variables
c=======================================================================
       print*,'Initializing variables...'
       if (cloudt.eq.0) then
          cloudz=50
       else
          cloudz=cloudh(cloudt)
       endif
       prmaps=1
       iun=0
       ideux=1
       flcumu=0.
       icloud=0.
       do i=1,width
        do j=1,width
         val2d(i,j)=0.
         altsol(i,j)=0.
         srefl(i,j)=0.
         inclix(i,j)=0.
         incliy(i,j)=0.
         lpluto(i,j)=0.
         ITC(i,j)=0.
         FC(i,j)=0.
         FTC(i,j)=0.
         FTCN(i,j)=0.
         FCA(i,j)=0.
         do k=1,120
          lamplu(i,j,k)=0.
          lampal(i,j,k)=0.
          ITT(i,j,k)=0.
         enddo
        enddo
       enddo
       do i=1,181
        fdifa(i)=0.
        fdifan(i)=0.
        anglea(i)=0.
        do j=1,120
         pval(i,j)=0.
         pvalno(i,j)=0.
        enddo
       enddo  
       do i=1,1024
        do j=1,3
         lcible(i,j)=1
        enddo
       enddo
       do i=1,3000000
        do j=1,4
         zondif(i,j)=1
        enddo
       enddo     
       irefdi=0.
       angmin=0.
       vistep=1
c***********************************************************************
c        reading of the environment variables                          *
c***********************************************************************
c=======================================================================
c  reading of the elevation file
c=======================================================================
       call intrants2d(mnaf,altsol,xcell0,ycell0,pixsiz,
     + nbx,nby)

       latitu=ycell0

       Hmin=3000000.
       do i=1,nbx                                                         ! beginning of the loop over all cells along x.
        do j=1,nby                                                        ! beginning of the loop over all cells along y.
c                                                                         ! searching of the Height minimale.
         if (Hmin.gt.altsol(i,j)) Hmin=altsol(i,j)
        enddo                                                             ! end of the loop over all cells along y.
       enddo 
       do i=1,nbx                                                         ! beginning of the loop over all cells along x.
        do j=1,nby                                                        ! beginning of the loop over all cells along y.
         altsol(i,j)=altsol(i,j)-Hmin                                     ! subtraction of the Minimum ground elevation
        enddo                                                             ! end of the loop over all cells along y.
       enddo
c=======================================================================
c reading reflectance file
c=======================================================================
       call intrants2d(reflf,srefl,xcell0,ycell0,
     + pixsiz,nbx,nby)
       do i=1,nbx                                                         ! beginning of the loop over all cells along x.
        do j=1,nby                                                        ! beginning of the loop over all cells along y.
         if (srefl(i,j).lt.0.) then                                       ! searching of of the negative reflectances
           print*,'***,WARNING - Negative reflectance replacing by 0.!'
           srefl(i,j)=0.
         endif
        enddo                                                             ! end of the loop over all cells along y.
       enddo
c=======================================================================
c  reading of the values of P(theta), height, luminosities and positions 
c   of the sources, obstacle height and distance
c=======================================================================
c
       ohfile=basenm(1:lenbase)//'_obsth.pgm'
       odfile=basenm(1:lenbase)//'_obstd.pgm'
       alfile=basenm(1:lenbase)//'_altlp.pgm'                             ! setting the file name of height of the sources lumineuse.
       dtheta=.017453293                                                  ! one degree
       do stype=1,ntype                                                   ! beginning of the loop 1 for the 120 types of sources.
        imin(stype)=nbx
        jmin(stype)=nby
        imax(stype)=1
        jmax(stype)=1       
        pvalto=0.
        write(lampno, '(I3.3)' ) stype                                    ! support of 120 different sources (3 digits)
        pafile=basenm(1:lenbase)//'_fctem_'//lampno//'.dat'               ! setting the file name of angular photometry.
        lufile=basenm(1:lenbase)//'_lumlp_'//lampno//'.pgm'               ! setting the file name of the luminosite of the cases.
c    ===================================================================
c    reading photometry files
        open(UNIT=1, FILE=pafile,status='OLD')                            ! opening file pa#.dat, angular photometry.
        do i=1,181                                                        ! beginning of the loop for the 181 data points
         read(1,*) pval(i,stype)                                          ! reading of the data in the array pval.
         pvalto=pvalto+pval(i,stype)*2.*pi*                               ! Sum of the values of the  photometric function 
     a   sin(real(i-1)*dtheta)*dtheta                                     ! (pvaleur x 2pi x sin theta x dtheta) (ou theta egale 
c                                                                         ! (i-1) x 1 degrees).
        enddo                                                             ! end of the loop over the 181 donnees of the fichier pa#.dat.
        close(1)                                                          ! closing file pa#.dat, angular photometry.
        do i=1,181
         if (pvalto.ne.0.) pvalno(i,stype)=pval(i,stype)/pvalto           ! Normalisation of the photometric function.
        enddo   
c    ===================================================================
c    reading luminosity files
        call intrants2d(lufile,val2d,xcell0,ycell0,pixsiz,
     +  nbx,nby)
       do i=1,nbx                                                         ! beginning of the loop over all cells along x.
        do j=1,nby                                                        ! beginning of the loop over all cells along y.
         if (val2d(i,j).lt.0.) then                                       ! searching of negative fluxes
           print*,'***Negative lamp flux!, stopping execution'
           stop
         endif
        enddo                                                             ! end of the loop over all cells along y.
       enddo     
        do i=1,nbx                                                        ! searching of the smallest rectangle containing the zone
         do j=1,nby                                                       ! of non-null luminosity to speedup the calculation
          if (val2d(i,j).ne.0.) then
           if (i-1.lt.imin(stype)) imin(stype)=i-2
           if (imin(stype).lt.1) imin(stype)=1
           goto 333
          endif
         enddo 
        enddo
        imin(stype)=1   
 333    do i=nbx,1,-1
         do j=1,nby
          if (val2d(i,j).ne.0.) then
           if (i+1.gt.imax(stype)) imax(stype)=i+2    
           if (imax(stype).gt.nbx) imax(stype)=nbx
           goto 334
          endif
         enddo
        enddo
        imax(stype)=1
 334    do j=1,nby
         do i=1,nbx
          if (val2d(i,j).ne.0.) then
           if (j-1.lt.jmin(stype)) jmin(stype)=j-2 
           if (jmin(stype).lt.1) jmin(stype)=1
           goto 335
          endif
         enddo
        enddo 
        jmin(stype)=1
 335    do j=nby,1,-1
         do i=1,nbx
          if (val2d(i,j).ne.0.) then
           if (j+1.gt.jmax(stype)) jmax(stype)=j+2
           if (jmax(stype).gt.nby) jmax(stype)=nby
           goto 336
          endif
         enddo
        enddo  
        jmax(stype)=1
 336    do i=1,nbx                                                        ! beginning of the loop over all cells along x.
         do j=1,nby                                                       ! beginning of the loop over all cells along y.
          lamplu(i,j,stype)=val2d(i,j)                                    ! remplir the array of the lamp type: stype
          totlu(stype)=totlu(stype)+lamplu(i,j,stype)                     ! the total lamp flux should be non-null to proceed to the calculations
         enddo                                                            ! end of the loop over all cells along y.
        enddo                                                             ! end of the loop over all cells along x.
        step(stype)=1
       enddo                                                              ! end of the loop 1 over the 120 types of sources. 
c    ==================================================================
c    reading lamp heights
        call intrants2d(alfile,val2d,xcell0,ycell0,pixsiz,nbx,nby)
         do i=1,nbx                                                       ! beginning of the loop over all cells along x.
           do j=1,nby                                                     ! beginning of the loop over all cells along y.
             lampal(i,j,stype)=val2d(i,j)                                 ! filling of the array for the lamp stype
           enddo                                                          ! end of the loop over all cells along y.
         enddo                                                            ! end of the loop over all cells along x.
c    ==================================================================
c    reading subgrid obstacles average height
        call intrants2d(ohfile,val2d,xcell0,ycell0,pixsiz,nbx,nby)
        do i=1,nbx                                                        ! beginning of the loop over all cells along x.
         do j=1,nby                                                       ! beginning of the loop over all cells along y.
          obsH(i,j)=val2d(i,j)                                            ! filling of the array
         enddo                                                            ! end of the loop over all cells along y.
        enddo 
c    ==================================================================
c    reading subgrid obstacles average distance
        call intrants2d(odfile,val2d,xcell0,ycell0,pixsiz,nbx,nby)
        do i=1,nbx                                                        ! beginning of the loop over all cells along x.
         do j=1,nby                                                       ! beginning of the loop over all cells along y.
          drefle(i,j)=val2d(i,j)                                          ! Filling of the array
          if (drefle(i,j).eq.0.) drefle(i,j)=10000000.                    ! when outside a zone, block to the theoritical horizon
         enddo                                                            ! end of the loop over all cells along y.
        enddo    
c=======================================================================
c        reading of the scattering parameters 
c=======================================================================
       open(unit = 1, file = diffil,status= 'old')                        ! opening file containing the parameters of scattering.
c                                                                         ! the scattering file is generated by the program imies 
c                                                                         ! of the progiciel AODSEM (Martin Aube).
        read(1,*)                                                           
        read(1,*)
        read(1,*)
        do i=1,181
         read(1,*) anglea(i), fdifa(i)                                    ! reading of the Scattering functions and the associate angle a 
c                                                                         ! this fonction of 0 a 180 degrees soit 181 lignes.
         fdifan(i)=fdifa(i)/pix4                                          ! Normalisation of the fonction a 4 pi (the integral of the 
c                                                                         ! fonction provided over all solid angles the doit etre egale a 4 pi).
c                                                                         ! in fact the file .mie.out is normalized ainsi (revefie par 
c                                                                         ! M. Aube en avril 2009)
        enddo
        do i = 1,7
         read(1,*)
        enddo
        read(1,*) extinc                                                  ! reading of the cross section extinction of the aerosols.
        read(1,*) scatte                                                  ! reading of the cross section of scattering of the aerosols.
       close(1)
       secdif=scatte/extinc                                               ! Rapport (sigmadif/sigmatotal).
c======================================================================
c        Quelques operations preparatoires
c======================================================================
       dy=dx                                                              ! we consider que the echelle is the same over the two axes
       z_obs=cellh(zcello)                                                ! Attribution of the value in meter to the position z of the observateur.
       largx=dx*real(nbx)                                                 ! computation of the Width along x of the case.
       largy=dy*real(nby)                                                 ! computation of the Width along y of the case.

       write(2,*) 'Width of the domain [NS](m):',largx,'#cases:',nbx
       write(2,*) 'Width of the domain [EO](m):',largy,'#cases:',nby
       write(2,*) 'Taille d''a cell (m):',dx,' X ',dy
       write(2,*) 'latitu south-west:',ycell0,' Longituof south-west:',
     + xcell0
c=======================================================================
c        computation of the tilt of the cases along x and along y
c=======================================================================
       do i=1,nbx                                                         ! beginning of the loop over the column (longitude) of the domain.
        do j=1,nby                                                        ! beginning of the loop over the ranges (latitu) of the domain.
         if (i.eq.1) then                                                 ! specific case close to the border of the domain (vertical side left).
          inclix(i,j)=atan((altsol(i+1,j)-altsol(i,j))/real(dx))          ! computation of the tilt along x of the surface.
         elseif (i.eq.nbx) then                                           ! specific case close to the border of the domain (vertical side right).
          inclix(i,j)=atan((altsol(i-1,j)-altsol(i,j))/(real(dx)))        ! computation of the tilt along x of the surface.
         else
          inclix(i,j)=atan((altsol(i+1,j)-altsol(i-1,j))/(2.              ! computation of the tilt along x of the surface.
     1    *real(dx)))
         endif
         if (j.eq.1) then                                                 ! specific case close to the border of the domain (horizontal side down).
          incliy(i,j)=atan((altsol(i,j+1)-altsol(i,j))/(real(dy)))        ! computation of the tilt along y of the surface.
         elseif (j.eq.nby) then                                           ! specific case close to the border of the domain (horizontal side up).
          incliy(i,j)=atan((altsol(i,j-1)-altsol(i,j))/(real(dy)))        ! computation of the tilt along y of the surface.
         else
          incliy(i,j)=atan((altsol(i,j+1)-altsol(i,j-1))/(2.              ! computation of the tilt along y of the surface
     1    *real(dy)))
         endif
        enddo                                                             ! end of the loop over the ranges (latitu) of the domain
       enddo                                                              ! end of the loop over the column (longitude) of the domain
c=======================================================================
c        beginning of the loop over the target cells
c=======================================================================
       call lignevisee(x_obs,y_obs,z_obs,dx,dy,angvis,                    ! Determination of the viewing line (target cells).
     + azim,nbx,nby,vistep,cloudz,lcible,ncible)
       fctcld=0.
       ftocap=0.                                                          ! Initialisation of the value of flux received by the sensor
       fcapt=1.
       do icible=1,ncible                                                 ! beginning of the loop over the target cells
      if ((fcapt.ge.ftocap/stoplim).or.(cloudt.ne.0)) then                  ! stop the calculation of the viewing line when the increment is lower than 1/stoplim
        if (fcapt.eq.1.) fcapt=0.
        if (icible.ge.nvis0) then                                         ! beginning condition for continuing of a computation stopped
         itotci=0.                                                        ! Initialisation of the contribution of the target at the sensor level
         do i=1,nbx
          do j=1,nby
            ITC(i,j)=0.
          enddo
         enddo
         zcellc=lcible(icible,3)                                          ! Definition of the position (cell) vertical of the target
         z_c=cellh(zcellc)                                                ! Definition of the position (metre) vertical of the target
         y_c=lcible(icible,2)                                             ! Definition of the position (cell) of the target
         x_c=lcible(icible,1)                                             ! Definition of the position (cell) of the target
         print*,'=================================================='
         print*,' Progression along the line of sight :',
     +   icible,'/',ncible,'(',x_c,',',y_c,')'
         print*,' Voxel height =',z_c,' m'
         print*,' Voxel thickness =',cthick(zcellc),' m'
         write(2,*) '=================================================='
         write(2,*) ' Progression along the line of sight :',
     +   icible,'/',ncible,'(',x_c,',',y_c,')'
         write(2,*) ' Voxel height =',z_c,' m'
      write(2,*) ' Voxel thickness =',cthick(zcellc),' m'
         if( (x_c.gt.nbx).or.(x_c.lt.1).or.(y_c.gt.nby).or.(y_c.lt.1)     ! Condition target cell inside the modelling domain
     +      .or.(zcellc.gt.50).or.(zcellc.lt.1) )then
         else
          if((x_c.eq.x_obs).and.(y_c.eq.y_obs).and.                       ! for le moment, if the target cell is the observer cell, 
c                                                                         ! we do not compute the scattered flux
     +    (zcellc.eq.zcello))then
           if (verbose.eq.1) then
             print*,'Scat voxel = Observer voxel' 
           endif
          else
           zcdown=z_c-0.5*cthick(zcellc)                                  ! lower limit of the target cell.
           zcup=z_c+0.5*cthick(zcellc)                                    ! upper limit of the target cell.
c=======================================================================
c        beginning of the loop over the types of light sources
c=======================================================================
           do stype=1,ntype                                               ! beginning of the loop over the source types.
            if (totlu(stype).ne.0.) then                                  ! check if there are any flux in that source type
                                                                          ! otherwise skip this lamp
            print*,' Turning on lamp',stype
            write(2,*) ' Turning on lamp',stype
            itotty=0.                                                     ! Initialisation of the contribution of a source types to 
c                                                                         ! the intensity toward the sensor by a target cell.
            do x_s=1,nbx
             do y_s=1,nby
              ITT(x_s,y_s,stype)=0.
             enddo
            enddo     
            do x_s=imin(stype),imax(stype),step(stype)                    ! beginning of the loop over the column (longitude the) of the domain.
             do y_s=jmin(stype),jmax(stype),step(stype)                   ! beginning of the loop over the rangees (latitud) of the domain.
              if (lamplu(x_s,y_s,stype) .ne. 0.) then                     ! if the luminosite of the case is nulle, le programme ignore this case.
               z_s=(altsol(x_s,y_s)+lampal(x_s,y_s,stype))                ! Definition of the position (metre) vertical of the source.
c computation of the distance source-target-observer if this distance is lower than  dx/2, pas of computation effectue
c the raison is que autrement on passe par of the cells tres proches of the source and on is jamais dans of telles
c conditions lorsqu'on observe le ciel. C is un probleme cree par le fait que the sources and l observateur
c sont toujours considered au centre of the cells.
               dsco=sqrt((real(x_s-x_c)*dx)**2.+(real(y_s-y_c)*dx)**2.+
     +         (z_s-z_c)**2.)+sqrt((real(x_obs-x_c)*dx)**2.+(real(y_obs
     +         -y_c)*dx)**2.+(z_obs-z_c)**2.)
          if (dsco.ge.dminlp) then                                        ! beginning condition distance source-target-observer >= dx/2

c **********************************************************************************************************************
c *     computation of the direct intensity toward the sensor by a target cell en provenance of the source         *
c **********************************************************************************************************************         
               dirck=0                                                    ! Initialisation of the verification of the position of the source.
               if ( (x_s.eq.x_c).and.(y_s.eq.y_c).and.( abs(z_s-z_c)      ! if the positions x and y of the source and the target are the 
c                                                                         ! memes alors.
     +         .lt.(cthick(zcellc)/2.) ) )then
                dirck=1
                if (verbose.eq.1) then
                 print*,'Source insiof scat voxel' 
                endif
               endif                                                      ! end of the case positions x and y source and target identiques.
               if (dirck.ne.1) then                                       ! the source is not at the target cell position
c=======================================================================
c        computation of the angle zenithal between the source and the target
c=======================================================================
c
c computation of the horizon for the resolved shadows direct              ! Il y a horizon par target cell resolution of 1 deg
         

                call anglezenithal
     +          (x_s,y_s,z_s,x_c,y_c,z_c,dx,dy,angzen)                    ! computation of the angle zenithal between the source and the target cell.
                call angleazimutal(x_s,y_s,x_c,y_c,dx,dy,angazi)          ! computation of the angle azimutal direct target-source
                az=nint(angazi*180./pi)+1
                d2=sqrt((real(x_s-x_c)*dx)**2.+(real(y_s-y_c)*dy)**2.)    ! max dist for the horizon (i.e. horizon limitations farter than cell-dif is not considered)
                call horizon(x_s,y_s,z_s,d2,altsol,nbx,nby,dx,dy,
     +          zhoriz,latitu,angazi)
                if ((angzen).lt.zhoriz(az)) then                          ! the line target-source n'est pas below the horizon => on calcule
c                                                                         ! beginning condition below the horizon direct
c sub-grid obstacles             
                 angmin=pi/2.-atan((altsol(x_s,y_s)+obsH(x_s,y_s)
     +           -z_s)/drefle(x_s,y_s))
                 if (angzen.lt.angmin) then                               ! beginning condition sub-grid obstacles direct.
c
c=======================================================================
c computation of the transmittance between the source and the target
c=======================================================================
                  angaz=zero
                  call transmitm(angzen,angaz,x_s,y_s,z_s,x_c,y_c,z_c,
     +            lambda,dx,dy,pressi,transm)     
                  call transmita(angzen,angaz,x_s,y_s,z_s,x_c,y_c,z_c,
     +            dx,dy,taua,transa)
c=======================================================================
c computation of the Solid angle of the par the target vue of the source
c=======================================================================

c                omega2=0.

                  xc=dble(x_c)*dble(dx)                                   ! Position in meters of the observer cell (longitude).
                  yc=dble(y_c)*dble(dy)                                   ! Position in meters of the observer cell (latitu).
                  zc=dble(z_c)                                            ! Position in meters of the observer cell (altitude).
                  xn=dble(x_s)*dble(dx)                                   ! Position in meters of the source (longitude).
                  yn=dble(y_s)*dble(dy)                                   ! Position in meters of the source (latitu).
                  zn=dble(z_s)                                            ! Position in meters of the source (altitude).
c    ------------------------------------
c    solid angle for the central plane xy
c    ------------------------------------
                  if (z_c .ne. z_s) then
                   call planxy(dx,dy,xc,xn,yc,yn,zc,zn,
     +             r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,
     +             r4z) 
                   call anglesolide(omega,r1x,r1y,r1z,                    ! Appel of the routine anglesoliof to compute the solid angle 
     +             r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                   ! along the surface xy.
                   omega1 = omega
                  else
                   omega1=0.
                  endif


c                  omega2=omega2+omega1


c     ------------------------------------
c     solid angle for the central plane zx
c     ------------------------------------
                  if (y_c .ne. y_s) then                                  ! if the latitu of the observer cell is the meme que celle
c                                                                         ! of the source cell, on ne calcule pas the angle solide
c                                                                         ! for the surface zx car il is egal a 0
                   call planzx(dx,xc,xn,yc,yn,zc,zn,cthick,
     +             zcellc,r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y
     +             ,r4z)
                   call anglesolide(omega,r1x,r1y,r1z,                    ! Appel of the routine anglesoliof to compute the solid angle 
     +             r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                   ! along the surface zx.
                  else
                   omega=0.
                  endif
                  if (omega.gt.0.) then
                   if (omega .gt. omega1) omega1 = omega                  ! On garof the solid angle le plus grand jusqu'a present.
                  endif

c                  omega2=omega2+omega1


c     ------------------------------------
c     solid angle for the central plane yz
c     ------------------------------------
                  if (x_c .ne. x_s) then                                  ! if the longituof of the observer cell is the meme que celle
c                                                                         ! of the source cell, on ne calcule pas the angle solide
c                                                                         ! for the surface yz car il is egal a 0.
                   call planyz(dy,xc,xn,yc,yn,zc,zn,cthick,
     +             zcellc,r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,
     +             r4z)
                   call anglesolide(omega,r1x,r1y,r1z,                    ! Routine anglesoliof to compute the solid angle along the surface yz.
     +             r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)
                  else 
                   omega=0.
                  endif
                  if (omega.gt.0.) then
                   if (omega .gt. omega1) omega1 = omega                  ! On garof the solid angle le plus grand
                  endif
                  omega=omega1


c                  omega2=omega2+omega1
c                  omega=omega2


c=======================================================================
c    isimation of the half of the underlying angle of the solid angle    ! this angle servira a obtenir un meilleur isime (moyenne) of 
c                                                                         ! P_dir for le cas of grans solid angles the ou pvalno 
c=======================================================================  ! varie significativement sur +- ouvang.
                  ouvang=sqrt(omega/pi)                                   ! Angle in radian.
                  ouvang=ouvang*180./pi                                   ! Angle in degrees.
c   
c=======================================================================
c        computation of the photometric function of the source toward the target
c=======================================================================
c   
                  anglez=nint(angzen/pi*180.)
                  if (anglez.lt.0) anglez=-anglez
                  if (anglez.gt.180) anglez=360-anglez
                  anglez=anglez+1                                         ! Transformer the angle in degree entier en position dans the array.
c
c  moyenner sur +- ouvang	
c
                  naz=0

                  nbang=0.
                  P_dir=0.
                  do na=-nint(ouvang),nint(ouvang)
                   naz=anglez+na
                   if (naz.lt.0) naz=-naz
                   if (naz.gt.181) naz=362-naz                            ! symetric function
                   P_dir=P_dir+pvalno(naz,stype)
                   nbang=nbang+1.
                  enddo
                  P_dir=P_dir/nbang
c
c=======================================================================
c        computation of the flux direct reaching the target cell
c=======================================================================
                  fldir=lamplu(x_s,y_s,stype)*P_dir*omega*
     1            transm*transa
c=======================================================================
c   computation of the scattering probability of the direct light
c=======================================================================
                  if (angzen.lt.(pi/2.)) then                             ! Attribution of the initial and final limit of the parcours of 
c                                                                         ! scattering dans the cell.
                   zidif=zcdown
                   zfdif=zcup
                  else
                   zidif=zcup
                   zfdif=zcdown
                  endif
                  angaz=angazi
                  call transmitm (angzen,angaz,iun,iun,zidif,ideux,iun,         ! Transmittance moleculaire of the scattering cell.
     +            zfdif,lambda,dx,dy,pressi,tran1m)
                  call transmita (angzen,angaz,iun,iun,zidif,ideux,iun,         ! Transmittance aerosols of the scattering cell.
     +            zfdif,dx,dy,taua,tran1a)
                  call angle3points (x_s,y_s,z_s,x_c,y_c,z_c,x_obs,       ! scattering angle.
     +            y_obs,z_obs,dx,dy,angdif)
                  call diffusion(omega,angdif,tran1a,tran1m,              ! scattering probability of the direct light.     
     +            secdif,fdifan,pdifdi)
c=======================================================================
c   computation of the source contribution a the direct intensity toward the sensor by a target cell
c=======================================================================
                  intdir=fldir*pdifdi

                if (cloudt.ne.0) then                                     ! target cell = cloud
                  if (cloudh(cloudt).eq.zcellc) then
                     call anglezenithal(x_c,y_c,z_c,x_obs,y_obs,z_obs,
     +               dx,dy,azencl)                                        ! zenith angle from cloud to observer                     
                     call cloudreflectance(angzen,cloudt,rcloud)          ! cloud intensity from direct illum
                     icloud=icloud+
     +               fldir*rcloud*abs(cos(azencl))/pi
                  endif
                endif
                 else 
                  intdir=0.                                      
                 endif                                                    ! end condition sub-grid obstacles direct.
                else
                endif                                                     ! end condition below the horizon direct? 
               endif                                                      ! end of the case Position Source is not equal to the target position


c        print*,'deb3',intdir,fldir,pdifdi,
c     +  fldir,lamplu(x_s,y_s,stype),P_dir,omega,
c     +  transm,transa
c        print*,omega,angdif,tran1a,tran1m,secdif,pdifdi    
c        print*,x_s,y_s,z_s,x_c,y_c,z_c,x_obs,y_obs,z_obs 
c ok=lamplu,fldir
c        if (icible.eq.23) stop



c  end of the computation of the direct intensity
c **********************************************************************************************************************
c * computation of the indirect intensity toward the sensor by a target cell en provenance of the source           *
c **********************************************************************************************************************
c=======================================================================
c        etablissement of the conditions ands boucles
c=======================================================================
               itotind=0.                                                 ! Initialisation of the indirect intensity of the source target    
               itotrd=0.
       boxx=nint(drefle(x_s,y_s)/dx)                                      ! Number of column to consider left/right of the source 
c                                                                         ! for the reflexion.
       boxy=nint(drefle(x_s,y_s)/dy)                                      ! Number of column to consider up/down of the source for 
c                                                                         ! the reflexion.
               do x_sr=x_s-boxx,x_s+boxx                                  ! beginning of the loop over the column (longitude) reflectrices.
                do y_sr=y_s-boxy,y_s+boxy                                 ! beginning of the loop over the ranges (latitu) relfectrices.
                 irefl=0.
                 z_sr=altsol(x_sr,y_sr)   
                  if( (x_sr.gt.nbx).or.(x_sr.lt.1).or.(y_sr.gt.nby)
     +            .or.(y_sr.lt.1) )then  
                   if (verbose.eq.1) then
                    print*,'Ground cell out of the borders'
                   endif
                  else  
                   if((x_s.eq.x_sr).and.(y_s.eq.y_sr).and.(z_s.eq.z_sr))
     +             then
                    if (verbose.eq.1) then
                     print*,'Source pos = Ground cell' 
                    endif
                   else
                    if (srefl(x_sr,y_sr).ne.0.) then                      ! Condition: the surface reflectance is not null
                     haut=-real(x_s-x_sr)*dx*tan(inclix(x_sr,y_sr))       ! if haut is negative, the ground cell is lighted from below
     1               -real(y_s-y_sr)*dy                                 
     2               *tan(incliy(x_sr,y_sr))+z_s-z_sr
                     if (haut .gt. 0.) then                               ! Condition: the ground cell is lighted from above
c=======================================================================
c        computation of the angle zenithal between the source and the  surface reflectance
c=======================================================================
                      call anglezenithal(x_s,y_s,z_s,x_sr,y_sr,z_sr,dx,   ! computation of the angle zenithal between the source and the target cell.
     +                dy,angzen)                                          ! end of the case "observateur a the meme latitu/longituof que the source".

c=======================================================================
c        computation of the transmittance between the source and the ground surface
c=======================================================================
                      angaz=zero      
                      call transmitm(angzen,angaz,x_s,y_s,z_s,x_sr,y_sr,
     +                z_sr,lambda,dx,dy,pressi,transm)          
                      call transmita(angzen,angaz,x_s,y_s,z_s,x_sr,y_sr,
     +                z_sr,dx,dy,taua,transa)
c=======================================================================
c     computation of the Solid angle of the reflecting cell seen from the source
c=======================================================================
                      xc=dble(x_sr)*dble(dx)                              ! Position in meters of the observer cell (longitude).
                      yc=dble(y_sr)*dble(dy)                              ! Position in meters of the observer cell (latitu).
                      zc=dble(z_sr)                                       ! Position in meters of the observer cell (altitude).
                      xn=dble(x_s)*dble(dx)                               ! Position in meters of the source (longitude).
                      yn=dble(y_s)*dble(dy)                               ! Position in meters of the source (latitu).
                      zn=dble(z_s)                                        ! Position in meters of the source (altitude).
                      epsilx=inclix(x_sr,y_sr)                            ! tilt along x of the ground reflectance
                      epsily=incliy(x_sr,y_sr)                            ! tilt along x of the ground reflectance
                      if (dx.gt.drefle(x_s,y_s)*2.) then                  ! use a sub-grid surface when the mean free path to the ground is smaller than the cell size
                       if ((x_sr.eq.x_s).and.(y_sr.eq.y_s)) then
                        dxp=drefle(x_s,y_s)*2.
                       endif
                      else
                       dxp=dx
                      endif
                      if (dy.gt.drefle(x_s,y_s)*2.) then
                       if ((x_sr.eq.x_s).and.(y_sr.eq.y_s)) then         
                        dyp=drefle(x_s,y_s)*2.
                       endif
                      else
                       dyp=dy
                      endif              
                      r1x=xc-dble(dxp)/2.-xn                              ! computation of the composante along x of the first vector.
                      r1y=yc+dble(dyp)/2.-yn                              ! computation of the composante along y of the first vector.
                      r1z=zc-tan(dble(epsilx))*dble(dxp)/2.+tan(dble(
     +                epsily))*dble(dyp)/2.-zn                            ! computation of the composante en z of the first vector.
                      r2x=xc+dble(dxp)/2.-xn                              ! computation of the composante along x of the second vector.
                      r2y=yc+dble(dyp)/2.-yn                              ! computation of the composante along y of the second vector.
                      r2z=zc+tan(dble(epsilx))*dble(dxp)/2.+tan(dble(
     +                epsily))*dble(dyp)/2.-zn                            ! computation of the composante en z of the second vector.
                      r3x=xc-dble(dxp)/2.-xn                              ! computation of the composante along x of the third vector.
                      r3y=yc-dble(dyp)/2.-yn                              ! computation of the composante along y of the third vector.
                      r3z=zc-tan(dble(epsilx))*dble(dxp)/2.-tan(
     +                dble(epsily))*dble(dyp)/2.-zn                       ! computation of the composante en z of the third vector.
                      r4x=xc+dble(dxp)/2.-xn                              ! computation of the composante along x of the fourth vector.
                      r4y=yc-dble(dyp)/2.-yn                              ! computation of the composante along y of the fourth vector.
                      r4z=zc+tan(dble(epsilx))*dble(dxp)/2.-tan(
     +                dble(epsily))*dble(dyp)/2.-zn                       ! computation of the composante en z of the fourth vector.
                      call anglesolide(omega,r1x,r1y,r1z,                 ! Appel of the routine anglesoliof to compute the angle solide.
     +                r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z) 
c
c=======================================================================
c    isimation of the half of the underlying angle of the solid angle    ! this angle servira a obtenir un meilleur isime (moyenne) of 
c                                                                         ! P_dir for le cas of grans solid angles the ou pvalno
c=======================================================================  ! varie significativement sur +- ouvang.
                      ouvang=sqrt(omega/pi)                               ! Angle in radian.
                      ouvang=ouvang*180./pi                               ! Angle in degrees.
c   
c=======================================================================
c        computation of the photometric function of the lampadaire toward the  surface reflectance
c=======================================================================
c    
                      anglez=nint(angzen/pi*180.)
                      if (anglez.lt.0) anglez=-anglez
                      if (anglez.gt.180) anglez=360-anglez
                      anglez=anglez+1                                     ! Transformer the angle in degree entier en position dans the array.
c
c  moyenner sur +- ouvang	
c
c
                      nbang=0.
                      P_indir=0.
                      do na=-nint(ouvang),nint(ouvang)
                       naz=anglez+na
                       if (naz.lt.0) naz=-naz
                       if (naz.gt.181) naz=362-naz                        ! symetric function
                       P_indir=P_indir+pvalno(naz,stype)
                       nbang=nbang+1.
                      enddo
                      P_indir=P_indir/nbang
c 
c=======================================================================
c        computation of the flux reaching the reflecting cell
c=======================================================================
                      flrefl=lamplu(x_s,y_s,stype)*P_indir*
     a                omega*transm*transa
c=======================================================================
c        computation of the intensity reflechie leaving the  surface reflectance
c=======================================================================
                      irefl1=flrefl*srefl(x_sr,y_sr)/pi                   ! Le facteur 1/pi vient of the normalisation of the fonction 
                      if (effdif.gt.(dx+dy)/2.) then 
                       call reflexdbledif (x_sr,y_sr,z_sr,x_c,y_c,
     +                 zcellc,dx,dy,effdif,nbx,nby,stepdi,
     +                 irefl1,lambda,pressi,taua,zcup,
     +                 zcdown,secdif,fdifan,x_obs,y_obs,z_obs,
     +                 epsilx,epsily,irefdi,drefle,obsH,altsol,
     +                 latitu,cloudt,cloudh,icloud,stype)
                      endif
                      itotrd=itotrd+irefdi      
c
c  the projection apparente is calculee a partir of the produit scalaire of the vecteur normal a 
c  the reflecting surface and the line reflecting surface toward scattering cell ou cible
c  it is the cosine correction for the lambertian reflectance for finite elements
c         
                      projap=(-tan(epsilx)*real(x_c-x_sr)*dx-
     +                tan(epsily)*real(y_c-y_sr)*dy+1.*(cellh(
     +                zcellc)-z_sr))/(sqrt(tan(epsilx)**2.+tan(epsily)
     +                **2.+1.)*sqrt((real(x_c-x_sr)*dx)**2.+(real(y_c-
     +                y_sr)*dy)**2.+(cellh(zcellc)-z_sr)**2.))
c                                                                         ! no matter the direction we are taking the absolute value of cos theta 
c                                                                          
c verify if there is shadow between sr and target 

                 call anglezenithal(x_sr,y_sr,z_sr,x_c,y_c,z_c,dx,        ! zenithal angle between the reflecting surface and the target cell.
     +           dy,angzen)     
                 call angleazimutal(x_sr,y_sr,x_c,y_c,dx,dy,angazi)       ! computation of the azimutal angle reflect-cible
                 az=nint(angazi*180./pi)+1  
                 d2=sqrt((real(x_sr-x_c)*dx)**2.+(real(y_sr-y_c)*         ! max dist for the horizon between the source and the target
     +           dy)**2.)                 
                 call horizon(x_sr,y_sr,z_sr,d2,altsol,nbx,nby,dx,dy,
     +           zhoriz,latitu,angazi)         
                 if ((angzen).lt.zhoriz(az)) then                         ! the path target-reflec is not below the horizon => we compute
                 
                 
                      if (projap.lt.0.) projap=0.
                      irefl=irefl1*
     +                projap
                 endif                                                    ! end condition reflecting surf. above horizon
c=======================================================================
c        Case: target position = Position of reflecting cell
c=======================================================================
                      if((x_c.eq.x_sr).and.(y_c.eq.y_sr).and.
     +                (z_c.eq.z_sr)) then
                       intind=irefl
                      else
c
c            
c obstacle                 
                       angmin=pi/2.-atan(obsH(x_sr,y_sr)/
     +                 drefle(x_sr,y_sr))
                       if (angzen.lt.angmin) then                         ! beginning condition obstacle indirect.
c
c=======================================================================
c        computation of the transmittance between the  ground surface and the target cell
c=======================================================================
                        angaz=zero
                        call transmitm(angzen,angaz,x_sr,y_sr,z_sr,x_c,
     +                  y_c,z_c,lambda,dx,dy,pressi,transm)        
                        call transmita(angzen,angaz,x_sr,y_sr,z_sr,x_c,
     +                  y_c,z_c,dx,dy,taua,transa)
c=======================================================================
c     computation of the Solid angle of the par the target vue of the reflecting cell
c=======================================================================


c                omega2=0.

                        xc=dble(x_c)*dble(dx)                             ! Position in meters of the observer cell (longitude).
                        yc=dble(y_c)*dble(dy)                             ! Position in meters of the observer cell (latitu).
                        zc=dble(z_c)                                      ! Position in meters of the observer cell (altitude).
                        xn=dble(x_sr)*dble(dx)                            ! Position in meters of the source (longitude).
                        yn=dble(y_sr)*dble(dy)                            ! Position in meters of the source (latitu).
                        zn=dble(z_sr)                                     ! Position in meters of the source (altitude).
c    ------------------------------------
c    solid angle for the central plane xy
c    ------------------------------------
                        if (z_c .ne. z_sr) then
                         call planxy(dx,dy,xc,xn,yc,yn,zc,zn,
     +                   r1x,r1y,r1z,r2x,r2y,
     +                   r2z,r3x,r3y,r3z,r4x,r4y,r4z)
                         call anglesolide(omega,r1x,r1y,r1z,              ! Appel of the routine anglesolide to compute the solid angle 
     +                   r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)             ! along the surface xy.
                         omega1 = omega
                        else
                         omega1=0.
                        endif


c           omega2=omega2+omega1



c     ------------------------------------
c     solid angle for the central plane zx
c     ------------------------------------
                        if (y_c .ne. y_sr) then                           ! if the latitu of the observer cell is the meme que celle
c                                                                         ! of the source cell, on ne calcule pas the angle solide
c                                                                         ! for the surface zx car il is egal a 0.
                         call planzx(dx,xc,xn,yc,yn,zc,zn,
     +                   cthick,zcellc,r1x,r1y,r1z,r2x,r2y,
     +                   r2z,r3x,r3y,r3z,r4x,r4y,r4z)
                         call anglesolide(omega,r1x,r1y,r1z,              ! Appel of the routine anglesolide to compute the solid angle 
     +                   r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)             ! along the surface zx.
                        else
                         omega=0.
                        endif
                        if (omega.gt.0.) then
                         if (omega.gt.omega1) omega1 = omega              ! On garof the solid angle le plus grand jusqu'a present.
                        endif


c           omega2=omega2+omega1



c     ------------------------------------
c     solid angle for the central plane yz
c     ------------------------------------
                        if (x_c.ne.x_sr) then                             ! if the longituof of the observer cell is the meme que celle
c                                                                         ! of the source cell, on ne calcule pas the angle solide
c                                                                         ! for the surface yz car il is egal a 0.
                         call planyz(dy,xc,xn,yc,yn,zc,zn,
     +                   cthick,zcellc,r1x,r1y,r1z,r2x,r2y,
     +                   r2z,r3x,r3y,r3z,r4x,r4y,r4z)
                         call anglesolide(omega,r1x,r1y,r1z,              ! Appel of the routine anglesolide to compute the solid angle 
     +                   r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)             ! along the surface yz.
                        else 
                         omega=0.
                        endif
                        if (omega.gt.0.) then
                         if (omega.gt.omega1) omega1=omega                ! On garof the solid angle le plus grand.
                        endif
                        omega=omega1 


c           omega2=omega2+omega1
c           omega=omega2

    
c=======================================================================
c        computation of the flux indirect reaching the target cell
c=======================================================================
                        flindi=irefl*omega*transm*
     +                  transa     
                if (cloudt.ne.0) then                                     ! target cell = cloud
                  if (cloudh(cloudt).eq.zcellc) then
                     call anglezenithal(x_c,y_c,z_c,x_obs,y_obs,z_obs,
     +               dx,dy,azencl)                                        ! zenith angle from cloud to observer                     
                     call cloudreflectance(angzen,cloudt,rcloud)          ! cloud intensity from indirect illum
                     icloud=icloud+
     +               flindi*rcloud*abs(cos(azencl))/pi
                  endif
                endif
c=======================================================================
c   computation of the scattering probability of the indirect light
c=======================================================================
                        if (angzen.lt.(pi/2.)) then                       ! Attribution of the initial limit and finale of the parcours of 
c                                                                         ! scattering dans the cell.
                         zidif=zcdown
                         zfdif=zcup
                        else
                         zidif=zcup
                         zfdif=zcdown
                        endif 
                        angaz=angazi       
                        call transmitm(angzen,angaz,iun,iun,zidif,        ! Transmittance moleculaire of the scattering cell.
     +                  ideux,iun,zfdif,lambda,dx,dy,pressi,tran1m)
                        call transmita(angzen,angaz,iun,iun,zidif,        ! Transmittance aerosols of the scattering cell.
     +                  ideux,iun,zfdif,dx,dy,taua,tran1a)
                        call angle3points (x_sr,y_sr,z_sr,x_c,y_c,z_c,    ! scattering angle.
     +                  x_obs,y_obs,z_obs,dx,dy,angdif)
                        call diffusion(omega,angdif,tran1a,               ! scattering probability of the indirect light.
     +                  tran1m,secdif,fdifan,pdifin)
c=======================================================================
c   computation of the indirect intensity toward the sensor by a reflecting cell
c=======================================================================
                        intind=flindi*pdifin 
                       else
                        intind=0.
                       endif                                              ! end condition obstacle indirect.
                      endif                                               ! end of the case Posi reflecting cell =  target position                                 
                      itotind=
     a                itotind+intind                                      ! Somme of the intensitys of chaque reflecting cells propres 
c                                                                         ! source.
                     endif                                                ! end of the condition surface non-eclairee par le haut.
                    endif                                                 ! end of the condition reflectance non-nulle.
                   endif                                                  ! end of the condition reflecting cell n'est pas a source.
                  endif                                                   ! end of the condition surface of the domain.
                enddo                                                     ! end of the loop over the ranges (latitu) relfectrices.
               enddo                                                      ! end of the loop over the column (longitude) reflectrices.
c   end of the computation of the indirect intensity        
c **********************************************************************************************************************
c * computation of the scattered intensity toward the sensor by a target cell en provenance of the source            *
c **********************************************************************************************************************
c
c=======================================================================
c    Determination of the scattering cells en fonction of the source cell and the target cell
c=======================================================================

               itodif=0.                                                  ! Initialisation of the scattered intensity by a source dans 
c                                                                         ! a target cell calculer le double scattering seulement if 
               if (effdif.gt.(dx+dy)/2.) then                             ! le rayon of scattering is superieur a the taille of the cells.
                call zone_diffusion(x_s,y_s,z_s,x_c,y_c,zcellc,dx,dy,
     +          effdif,nbx,nby,altsol,zondif,ndiff)
                do idi=1,ndiff,stepdi                                     ! beginning of the loop over the scattering cells.
                 x_dif=zondif(idi,1)
                 y_dif=zondif(idi,2)
                 zceldi=zondif(idi,3)
                 z_dif=cellh(zceldi)             
                 if((x_dif.gt.nbx).or.(x_dif.lt.1).or.(y_dif.gt.nby).     ! Condition scattering cell of the domain.
     +           or.(y_dif.lt.1)) then     
c
c !!!!!!!rien ici???????
c          
                 else
                  if ((x_s.eq.x_dif).and.(y_s.eq.y_dif).and.(z_s.eq. 
     +            z_dif)) then
                   if (verbose.eq.1) then
                     print*,'Scat voxel = Source position'
                   endif
                  elseif ((x_c.eq.x_dif).and.(y_c.eq.y_dif).and. 
     +                 (z_c.eq.z_dif)) then
                  else
c=======================================================================
c        computation of the angle zenithal between the source and the scattering cell
c=======================================================================


c ombrage source-scattering cell

                   call anglezenithal(x_s,y_s,z_s,x_dif,y_dif,z_dif,dx,
     +             dy,angzen)                                             ! computation of the angle zenithal source-scattering cell. 
                   call angleazimutal(x_s,y_s,x_dif,y_dif,dx,dy,          ! computation of the angle azimutal cible-scattering cell
     +             angazi)
                   az=nint(angazi*180./pi)+1
                   d2=sqrt((real(x_dif-x_s)*dx)**2.+(real(y_dif-y_s)      ! max dist for the horizon (i.e. horizon limitations farter than cell-dif is not considered)
     +             *dy)**2.)
                   call horizon(x_s,y_s,z_s,d2,altsol,nbx,nby,
     +             dx,dy,zhoriz,latitu,angazi)
                   if ((angzen).lt.zhoriz(az)) then                       ! beginning condition ombrage source-diffusante
c                                                                   
c sub-grid obstacles               
                    angmin=pi/2.-atan((obsH(x_s,y_s)+
     +              altsol(x_s,y_s)-z_s)/drefle(x_s,y_s))
                    if (angzen.lt.angmin) then                            ! beginning condition obstacle source->diffuse.
c                                                                    
c=======================================================================
c        computation of the transmittance between the source and the scattering cell
c=======================================================================
                     angaz=zero
                     call transmitm(angzen,angaz,x_s,y_s,z_s,x_dif,
     +               y_dif,z_dif,lambda,dx,dy,pressi,transm)
                     call transmita(angzen,angaz,x_s,y_s,z_s,x_dif,
     +               y_dif,z_dif,dx,dy,taua,transa) 
c=======================================================================
c     computation of the Solid angle of the par the scattering cell vue of the source
c=======================================================================


c                omega2=0.


                     xc=dble(x_dif)*dble(dx)                              ! Position in meters of the scattering cell (longitude).
                     yc=dble(y_dif)*dble(dy)                              ! Position in meters of the scattering cell (latitu).
                     zc=dble(z_dif)                                       ! Position in meters of the scattering cell (altitude).
                     xn=dble(x_s)*dble(dx)                                ! Position in meters of the source (longitude).
                     yn=dble(y_s)*dble(dy)                                ! Position in meters of the source (latitu).
                     zn=dble(z_s)                                         ! Position in meters of the source (altitude).
c    ------------------------------------
c    solid angle for the central plane xy
c    ------------------------------------
                     if (z_dif .ne. z_s) then
                      call planxy(dx,dy,xc,xn,yc,yn,zc,zn,
     +                r1x,r1y,r1z,r2x,r2y,r2z,
     +                r3x,r3y,r3z,r4x,r4y,r4z)
                      call anglesolide(omega,r1x,r1y,r1z,                 ! Calling the routine anglesolide for the computation of the solid angle 
     +                r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                ! in the xy plane.
                      omega1 = omega
                     else
                      omega1=0.
                     endif


c           omega2=omega2+omega1



c     ------------------------------------
c     solid angle for the central plane zx
c     ------------------------------------
                     if (y_dif .ne. y_s) then                             ! if the latitude of the observer cell is the same as the one
c                                                                         ! of the source cell, we do not compute the solid angle
c                                                                         ! for le zx plane because is is null.
                      call planzx(dx,xc,xn,yc,yn,zc,zn,cthick,
     +                zcellc,r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x
     +                ,r4y,r4z)
                      call anglesolide(omega,r1x,r1y,r1z,                 ! Calling of the routine anglesoliof for the computation of the solid angle 
     +                r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                ! in the zx plane.
                     else
                      omega=0.
                     endif
                     if (omega.gt.0.) then
                      if (omega .gt. omega1) omega1 = omega               ! We keep the largest solid angle
                     endif


c           omega2=omega2+omega1



c     ------------------------------------
c     solid angle for the central plane yz
c     ------------------------------------
                     if (x_dif .ne. x_s) then                             ! if the longitude of the observer cell is the same as the 
c                                                                         ! source cell, we do not compute the solid angle
c                                                                         ! for the yz plane because it is null.
                      call planyz(dy,xc,xn,yc,yn,zc,zn,cthick,
     +                zcellc,r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,
     +                r4y,r4z)
                      call anglesolide(omega,r1x,r1y,r1z,                 ! Calling of the routine anglesoliof for the computation of the solid angle 
     +                r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                ! in the yz plane.       
                     else 
                      omega=0.
                     endif
                     if (omega.gt.0.) then
                      if (omega .gt. omega1) omega1 = omega               ! We keep the largest solid angle.
                     endif
                     omega=omega1


c           omega2=omega2+omega1
c           omega=omega2


c=======================================================================
c estimation of the subtended angle of the solid angle                    ! this angle will allow a better estimate (average) of 
c                                                                         ! P_dir for the case of large solid angles when pvalno
c=======================================================================  ! vary significatively in +- ouvang.
                     ouvang=sqrt(omega/pi)                                ! Angle in radian.
                     ouvang=ouvang*180./pi                                ! Angle in degrees.
c 
c=======================================================================
c Computing emission function of the source toward the scattering cell    
c=======================================================================
c    
                     anglez=nint(angzen/pi*180.)
                     if (anglez.lt.0) anglez=-anglez
                     if (anglez.gt.180) anglez=360-anglez
                     anglez=anglez+1                                      ! Transform the angle in degree integer into position inside the array.
c		
c  moyenner sur +- ouvang	
c
c
                     nbang=0.
                     P_dif1=0.
                     do na=-nint(ouvang),nint(ouvang)
                      naz=anglez+na
                      if (naz.lt.0) naz=-naz
                      if (naz.gt.181) naz=362-naz                         ! symetric function
                      if (naz.ne.0) then
                        P_dif1=P_dif1+pvalno(naz,stype)
                        nbang=nbang+1. 
                      endif
                     enddo
                     P_dif1=P_dif1/nbang 
c
c=======================================================================
c Computing flux reaching the scattering cell
c=======================================================================
                     fldif1=lamplu(x_s,y_s,stype)*P_dif1*
     +               omega*transm*transa
c=======================================================================
c Computing the scattering probability toward the line of sight cell
c=======================================================================
                     if (angzen.lt.(pi/2.)) then                          ! Attribution of the initial and final limits of the 
c                                                                         ! scattering path.
                      zidif=z_c-0.5*cthick(zceldi)
                      zfdif=z_c+0.5*cthick(zceldi)
                     else
                      zidif=z_c+0.5*cthick(zceldi)
                      zfdif=z_c-0.5*cthick(zceldi)
                     endif
                     angaz=angazi       
                     call transmitm (angzen,angaz,iun,iun,zidif,ideux,          ! Molecular transmittance of the scattering cell.
     +               iun,zfdif,lambda,dx,dy,pressi,tran1m)
                     call transmita (angzen,angaz,iun,iun,zidif,ideux,          ! Aerosol transmittance of the scattering cell.
     +               iun,zfdif, dx,dy,taua,tran1a)
                     call angle3points (x_s,y_s,z_s,x_dif,y_dif,z_dif,    ! scattering angle.
     +               x_c,y_c,z_c,dx,dy,angdif)
                     call diffusion(omega,angdif,tran1a,tran1m,           ! scattering probability of the direct light.
     +               secdif,fdifan,pdifd1)
c=======================================================================
c Computing scattered intensity toward the line of sight cell from the scattering cell  
c=======================================================================
                     idif1=fldif1*pdifd1
c=======================================================================
c Computing zenith angle between the scattering cell and the line of sight cell
c=======================================================================

                     call anglezenithal(x_dif,y_dif,z_dif,x_c,y_c,z_c,
     +               dx,dy,angzen)                                        ! computation of the zenithal angle between the scattering cell and the 
c                                                                         ! target cell.
        call angleazimutal(x_dif,y_dif,x_c,y_c,dx,dy,angazi)              ! computation of the azimutal angle surf refl-scattering cell
        az=nint(angazi*180./pi)+1
        d2=sqrt((real(x_dif-x_c)*dx)**2.+(real(y_dif-y_c)*dy)**2.)        ! max dist for the horiz (i.e. horizon limitations farter than cell-dif is not considered)
        call horizon(x_dif,y_dif,z_dif,d2,altsol,nbx,nby,dx,dy,
     +  zhoriz,latitu,angazi)
        if ((angzen).lt.zhoriz(az)) then                                  ! beginning shadow condition diffuse-cible  
c                                                                 
c subgrid obstacles                
                     angmin=pi/2.-atan((obsH(x_dif,y_dif)+
     +               altsol(x_dif,y_dif)-z_dif)/drefle(x_dif,y_dif))
                     if (angzen.lt.angmin) then                           ! beginning shadow condition sub-grid obstacles diffuse->target
c                                                                   
c=======================================================================
c Computing transmittance between the scattering cell and the line of sight cell
c=======================================================================
                      angaz=zero
                      call transmitm(angzen,angaz,x_dif,y_dif,z_dif,x_c
     +                ,y_c,z_c,lambda,dx,dy,pressi,transm)
                      call transmita(angzen,angaz,x_dif,y_dif,z_dif,x_c
     +                ,y_c,z_c,dx,dy,taua,transa) 
c=======================================================================
c Computing the solid angle of the line of sight cell as seen from the scattering cell
c=======================================================================
                      xc=dble(x_c)*dble(dx)                               ! Position in meters of the target cell (longitude).
                      yc=dble(y_c)*dble(dy)                               ! Position in meters of the target cell (latitu).
                      zc=dble(z_c)                                        ! Position in meters of the target cell (altitude).
                      xn=dble(x_dif)*dble(dx)                             ! Position in meters of the scattering cell (longitude).
                      yn=dble(y_dif)*dble(dy)                             ! Position in meters of the scattering cell (latitu).
                      zn=dble(z_dif)                                      ! Position in meters of the scattering cell (altitude).
c    ------------------------------------
c    solid angle for the central plane xy
c    ------------------------------------
                      if (z_c .ne. z_dif) then
                       call planxy(dx,dy,xc,xn,yc,yn,zc,zn,
     +                 r1x,r1y,r1z,r2x,r2y,r2z
     +                 ,r3x,r3y,r3z,r4x,r4y,r4z)
                       call anglesolide(omega,r1x,r1y,r1z,                ! Calling the routine anglesolide for the calculation of the solid angle 
     +                 r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)               ! in the xy plane.   
                       omega1 = omega
                      else
                       omega1=0.
                      endif
c     ------------------------------------
c     solid angle for the central plane zx
c     ------------------------------------
                      if (y_c .ne. y_dif) then                            ! if the latitude of the observer cell is the same as the
c                                                                         ! source cell, we do not calculate the solid angle
c                                                                         ! for the zx plane because it is null.
                       call planzx(dx,xc,xn,yc,yn,zc,zn,
     +                 cthick,zcellc,r1x,r1y,r1z,r2x,r2y,r2z,
     +                 r3x,r3y,r3z,r4x,r4y,r4z)
                       call anglesolide(omega,r1x,r1y,r1z,                ! Calling of the routine anglesolide for the calculation of the solid angle 
     +                 r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)               ! in the zx plane.
                      else
                       omega=0.
                      endif
                      if (omega.gt.0.) then
                       if (omega .gt. omega1) omega1 = omega              ! We keep the largest solid angle.
                      endif
c     ------------------------------------
c     solid angle for the central plane yz
c     ------------------------------------
                      if (x_c .ne. x_dif) then                            ! if the longitude of the observer cell is the same as the
c                                                                         ! source cell, we do not calculate the solid angle
c                                                                         ! for the yz plane because it is null.
                       call planyz(dy,xc,xn,yc,yn,zc,zn,
     +                 cthick,zcellc,r1x,r1y,r1z,r2x,r2y,r2z,
     +                 r3x,r3y,r3z,r4x,r4y,r4z)
                       call anglesolide(omega,r1x,r1y,r1z,                ! Calling the routine anglesolide for the calculation of the solid angle 
     +                 r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)               ! in the yz plane.
                      else 
                       omega=0.
                      endif
                      if (omega.gt.0.) then
                       if (omega .gt. omega1) omega1 = omega              ! We keep the largest solid angle.
                      endif
                      omega=omega1
c=======================================================================
c        computation of the scattered flux reaching the target cell
c=======================================================================
                      fldiff=idif1*omega*transm*
     +                transa
                if (cloudt.ne.0) then                                     ! target cell = cloud
                  if (cloudh(cloudt).eq.zcellc) then
                     call anglezenithal(x_c,y_c,z_c,x_obs,y_obs,z_obs,
     +               dx,dy,azencl)                                        ! zenith angle from cloud to observer                     
                     call cloudreflectance(angzen,cloudt,rcloud)          ! cloud intensity from direct illum
                     icloud=icloud+
     +               fldiff*rcloud*abs(cos(azencl))/pi
                  endif
                endif
c=======================================================================
c   computation of the scattering probability of the scattered light toward the observer cell (exiting cell_c)
c=======================================================================
                      if (angzen.lt.(pi/2.)) then                         ! Attribution of the initial and final limits of the path to the
c                                                                         ! scattering cell.
                       zidif=zcdown
                       zfdif=zcup
                      else
                       zidif=zcup
                       zfdif=zcdown
                      endif
                      angaz=angazi
                      call transmitm(angzen,angaz,iun,iun,zidif,ideux,         ! Molecular transmittance of the scattering cell.
     +                iun,zfdif,lambda,dx,dy,pressi,tran1m)
                      call transmita(angzen,angaz,iun,iun,zidif,ideux,         ! Aerosol transmittance of the scattering cell.
     +                iun,zfdif,dx,dy,taua,tran1a)    
                      call angle3points (x_dif,y_dif,z_dif,x_c,y_c,       ! scattering angle.
     +                z_c,x_obs,y_obs,z_obs,dx,dy,angdif)
                      call diffusion(omega,angdif,tran1a,tran1m,          ! scattering probability of the direct light.
     +                secdif,fdifan,pdifd2)
c=======================================================================
c Computing scattered intensity toward the observer from the line of sight cell
c=======================================================================
                      idiff2=fldiff*pdifd2
                      idiff2=
     +                idiff2*real(stepdi)                                 ! Correct the result for the skipping of 2nd scattering cells to accelerate the calculation
                      itodif=                        
     +                itodif+idiff2
                     endif                                                ! end condition obstacle scattering->target
       else
        endif                                                             ! end condition ombrage scattering-target                     
                    endif                                                 ! end condition obstacle source->scattering.
                   else
                   endif                                                  ! end condition shadow source-scattering
                  endif                                                   ! end of the case scattering = Source or target
                 endif                                                    ! end of the condition "cell of the domain".      
                enddo                                                     ! end of the loop over the scattering cells.
               endif                                                      ! end of the condition ou effdif > dx.
c End of 2nd scattered intensity calculations    
c**********************************************************************
c        computation of the intensity coming from a source to the target toward the sensor
c**********************************************************************
               isourc=intdir+itotind+itodif+itotrd                        ! Sum of the intensities of each type of source  
c                                                                         ! reaching the target cell.
c                                                                         ! in the order 1st scat; refl->1st scat; 1st scat->2nd scat, refl->1st scat->2nd scat
               if (verbose.eq.1) then
                print*,' Total intensity components:'
                print*,' source->scattering=',intdir
                print*,' source->reflexion->scattering=',
     +          itotind
                print*,' source->scattering->scattering=',
     +          itodif
                print*,' source->reflexion->scattering->scattering=',
     a          itotrd  
               endif
c                   
c**********************************************************************
c        computation of the total intensity coming from all the sources of a given type
c**********************************************************************
               itotty=itotty
     +         +isourc*real(step(stype)*step(stype))                      ! Sum of the intensities of each source.
                                                                          ! ITT stores itotty in a matrix
               ITT(x_s,y_s,stype)=ITT(x_s,y_s,stype)+isourc






          endif                                                           ! end condition distancesource-target-observer <= dx/2








              endif                                                       ! end of the condition "the luminosity of the ground pixel x_s,y_s in not null".
             enddo                                                        ! end the loop over the lines (latitude) of the domain (y_s).
            enddo                                                         ! end the loop over the column (longitude) of the domain (x_s).
c
c   end of the computation of the intensity of one source type
            itotci=itotci
     1      + itotty                                                      ! Sum of the intensities of each type to the target cell.
c interpolate ITT for fill the step(stype)
            if (step(stype).gt.1) then
             defval=0.
             autom=0
             intype=0
             window=real(step(stype))
             do ii=1,nbx
              do jj=1,nby
               dat(ii,jj)=0.
              enddo
             enddo
             do ii=imin(stype),imax(stype)
              do jj=jmin(stype),jmax(stype)
               dat(ii,jj)=ITT(ii,jj,stype)
              enddo
             enddo
             call interpmatrix(dat,imin(stype),imax(stype),jmin(stype),
     +       jmax(stype),intype,window,autom,defval)
             do ii=imin(stype),imax(stype)
              do jj=jmin(stype),jmax(stype)
               if (lamplu(ii,jj,stype).ne.0.) then
                ITT(ii,jj,stype)=dat(ii,jj)
               endif
              enddo
             enddo            
            endif
            do x_s=imin(stype),imax(stype)
             do y_s=jmin(stype),jmax(stype)
              ITC(x_s,y_s)=ITC(x_s,y_s)+ITT(x_s,y_s,stype)
             enddo   
            enddo  
c calculate lpluto 
            do x_s=1,nbx
             do y_s=1,nby
               lpluto(x_s,y_s)=lpluto(x_s,y_s)+   
     +         lamplu(x_s,y_s,stype)
             enddo
            enddo
           endif                                                          ! end of condition if there are any flux in that source type
           enddo                                                          ! end of the loop over the types of sources (stype).
c    end of the computation of the intensity coming from a target cell se dirigeant toward the sensor
c
c
c***********************************************************************
c        computation of the luminous flux reaching the cell ou se trouve the sensor
c***********************************************************************
c
c=======================================================================
c        computation of the angle zenithal between the observateur and the target
c=======================================================================
           call anglezenithal(x_c,y_c,z_c,x_obs,y_obs,z_obs,dx,dy,
     +     angzen)                                                        ! computation of the angle zenithal between the target cell and the observer.
c                                                                         ! end of the case "observateur a the meme latitu/longituof que the source".
c=======================================================================
c        computation of the transmittance between the target and the observer
c=======================================================================
           angaz=zero
           call transmitm(angzen,angaz,x_c,y_c,z_c,x_obs,y_obs,z_obs,
     +     lambda,dx,dy,pressi,transm)
           call transmita(angzen,angaz,x_c,y_c,z_c,x_obs,y_obs,z_obs,
     +     dx,dy,taua,transa)
c=======================================================================
c     computation of the Solid angle of the par the target vu par the observateur
c=======================================================================


c             omega2=0.


           xn=dble(x_obs)*dble(dx)                                        ! Position in meters of the observer cell (longitude).
           yn=dble(y_obs)*dble(dy)                                        ! Position in meters of the observer cell (latitu).
           zn=dble(z_obs)                                                 ! Position in meters of the observer cell (altitude).
           xc=dble(x_c)*dble(dx)                                          ! Position in meters of the target (longitude).
           yc=dble(y_c)*dble(dy)                                          ! Position in meters of the target (latitu).
           zc=dble(z_c)                                                   ! Position in meters of the target (altitude).
c    ------------------------------------
c    solid angle for the central plane xy
c    ------------------------------------
           if (z_c .ne. z_obs) then
            call planxy(dx,dy,xc,xn,yc,yn,zc,zn,
     +      r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)  
            call anglesolide(omega,r1x,r1y,r1z,                           ! Appel of the routine anglesolide to compute the solid angle 
     +      r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                          ! along the surface xy.
            omega1 = omega
           else
            omega1=0.
           endif


c           omega2=omega2+omega1


c     ------------------------------------
c     solid angle for the central plane zx
c     ------------------------------------
           if (y_c .ne. y_obs) then                                       ! if the latitu of the observer cell is the meme que celle
c                                                                         ! of the source cell, on ne calcule pas the angle solide
c                                                                         ! for the surface zx car il is egal a 0.
            call planzx(dx,xc,xn,yc,yn,zc,zn,cthick,zcellc,
     +      r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)
            call anglesolide(omega,r1x,r1y,r1z,                           ! Appel of the routine anglesolide to compute the solid angle 
     +      r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                          ! along the surface zx.
           else
            omega=0.
           endif
           if (omega.gt.0.) then
            if (omega.gt.omega1) omega1 = omega                           ! We keep the largest solid angle.
           endif


c           omega2=omega2+omega1



c     ------------------------------------
c     solid angle for the central plane yz
c     ------------------------------------
           if (x_c.ne.x_obs) then                                         ! if the longituof of the observer cell is the meme que celle
c                                                                         ! of the source cell, on ne calcule pas the angle solide
c                                                                         ! for the surface yz car il is egal a 0
            call planyz(dy,xc,xn,yc,yn,zc,zn,cthick,zcellc,
     +      r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)
            call anglesolide(omega,r1x,r1y,r1z,                           ! Appel of the routine anglesoliof to compute the solid angle 
     +      r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                          ! along the surface yz.
           else 
            omega=0.
           endif
           if (omega.gt.0.) then
            if (omega.gt.omega1) omega1=omega                             ! On garof the solid angle le plus grand.
           endif
           omega=omega1


c           omega2=omega2+omega1
c           omega=omega2


c=======================================================================
c        computation of the flux reaching the objectif of the telescope en provenance of the target cell
c=======================================================================
           dis_obs=sqrt((z_c-z_obs)**2.+((real(y_c-y_obs))*dy)**2.
     a     +((real(x_c-x_obs))*dx)**2.)
           ometif=pi*(diamobj/2.)**2./dis_obs**2.
           if (dis_obs.eq.0.) then
            print*,'ERROR problem with dis_obs',dis_obs
            stop
           endif
           flcib=itotci*ometif*transa*transm                              ! computation of the flux reaching the intrument from the line of sight cell
           do x_s=1,nbx
            do y_s=1,nby
             FC(x_s,y_s)=ITC(x_s,y_s)*ometif*transa*transm
            enddo
           enddo
           omefov=lfente*longfe/focal**2.                                 ! computation of the solid angle of the fente projete sur le ciel.
           if (cos(pi-angzen).eq.0.) then 
            print*,'ERROR perfectly horizontal sight is forbidden!'
            stop
           else
             portio=omefov/omega
c            portio=(omefov*dis_obs*dis_obs)/(cos(pi-angzen)*dx*dy)       ! Fraction of the target cell vue par le fov (Fraction peut 
c                                                                         ! etre superieure a 1). Le pi ici is du au fait
c                                                                         ! que angzen is calcule sur le trajand target toward the observateur
           endif
           if (omega.eq.0.) then
            print*,'ERROR omega=0 (1)'
            stop
           endif
           fcapt=flcib*portio                                             ! correction for the FOV to the flux reaching the intrument from the line of sight cell
           do x_s=1,nbx
            do y_s=1,nby
             FCA(x_s,y_s)=FC(x_s,y_s)*portio
            enddo
           enddo
c   end of the computation of the flux reaching the observer cell en provenance of the target cell
           ftocap=ftocap+fcapt  

           do x_s=1,nbx
            do y_s=1,nby
             FTC(x_s,y_s)=FTC(x_s,y_s)+FCA(x_s,y_s)                       ! FTC is the array of the flux total at the sensor level permettant d'identifier
                                                                          ! the contribution of chaque cell of the sol au flux total at the sensor level
                                                                          ! Le % is simplement donne par FTC/ftocap
             flcumu=flcumu+FCA(x_s,y_s)
            enddo
           enddo
          endif                                                           ! end of the condition target cell n'est pas observer cell.
         endif                                                            ! end of the condition target cell inside the modelling domain
        endif                                                             ! end condition for continuing of a computation stopped.
c correction for the FOV to the flux reaching the intrument from the cloud cell
           if (cloudt.ne.0) then
            if (cloudh(cloudt).eq.zcellc) then                           ! target cell = cloud
c=======================================================================
c  solid angle of the cloud pixel as seen from observer position
c=======================================================================
              xn=dble(x_obs)*dble(dx)                                     ! Position in meters of the observer cell (longitude).
              yn=dble(y_obs)*dble(dy)                                     ! Position in meters of the observer cell (latitu).
              zn=dble(z_obs)                                              ! Position in meters of the observer cell (altitude).
              xc=dble(x_c)*dble(dx)                                       ! Position in meters of the target (longitude).
              yc=dble(y_c)*dble(dy)                                       ! Position in meters of the target (latitu).
              zc=dble(z_c)                                                ! Position in meters of the target (altitude).
c    ------------------------------------
c    solid angle for the central plane xy
c    ------------------------------------
              if (z_c .ne. z_obs) then
                 call planxy(dx,dy,xc,xn,yc,yn,zc,zn,
     +           r1x,r1y,r1z,r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)  
                 call anglesolide(omega,r1x,r1y,r1z,                      ! Appel of the routine anglesoliof to compute the solid angle 
     +           r2x,r2y,r2z,r3x,r3y,r3z,r4x,r4y,r4z)                     ! along the surface xy.
              else
                 omega=0.
              endif
c computation of the flux reaching the intrument from the cloud cell
              fcloud=icloud*ometif*transa*transm
              fccld=fcloud*omefov/omega
              fctcld=fctcld+fccld
            endif
           endif          
        print*,' Flux @ sensor (clear & cloudy)             =',fcapt,
     +  fccld
        print*,' Flux @ sensor accumulated (clear & cloudy) =',ftocap,
     +  fctcld
        write(2,*) ' Flux sensor (clear & cloudy)             =',fcapt
     +  ,fccld
        write(2,*) ' Flux sensor accumulated (clear & cloudy) =',ftocap
     +  ,fctcld   
      endif                                                               ! end condition cell target 1/stoplim
       enddo                                                              ! end of the loop over the target cells.
       if (prmaps.eq.1) then
          open(unit=9,file=pclf,status='unknown')
          open(unit=8,file=pcwf,status='unknown')
            fctnto=0.
            ftcmax=0.
            do x_s=1,nbx
               do y_s=1,nby
                  FTC(x_s,y_s)=FTC(x_s,y_s)/ftocap   
                  if (FTC(x_s,y_s).gt.ftcmax) ftcmax=FTC(x_s,y_s)
                  if (lpluto(x_s,y_s).ne.0.) then
                  fctnto=fctnto+FTC(x_s,y_s)/lpluto(x_s,y_s)
                  endif
               enddo
            enddo
            if (verbose.eq.1) then
               print*,'Writing normalized contribution matrix'
            endif
            do x_s=1,nbx
               do y_s=1,nby
                  if (lpluto(x_s,y_s).ne.0.) then
                     FTCN(x_s,y_s)=(FTC(x_s,y_s)/lpluto(x_s,y_s))
     +               /fctnto  
                  else 
                     FTCN(x_s,y_s)=0.
                  endif                                                   ! FTCN is le % par unite of luminosite of the cell
                  write(9,*) x_s,y_s,FTC(x_s,y_s)                         ! emettrice au sol, c'est un % par unite of watt installes
                  write(8,*) x_s,y_s,FTCN(x_s,y_s)
               enddo
            enddo
            nom='Grid weight '
            valmax=65535       
            gain=ftcmax/real(valmax)
            offset=0.
            call extrants2d (pclimg,FTC,nom,xcell0,ycell0,pixsiz,
     +      gain,offset,nbx,nby,valmax)
            nom='NormGrid wgt'
            call extrants2d (pcwimg,FTCN,nom,xcell0,ycell0,pixsiz,
     +      gain,offset,nbx,nby,valmax)     
          close(unit=8)
          close(unit=9)
c creation of files gnuplot for the visualiser il faut betweenr gnuplot
c puis load 'fichier.gplot'
          open(unit=9,file=pclgp,status='unknown')
          open(unit=8,file=pcwgp,status='unknown')
            write(9,*) 'sand dgrid3d',nbx,',',nby
            write(9,*) 'sand hidden3d'
            write(9,*) 'sand pm3d'
            write(9,*) 'splot "'//basenm(1:lenbase)//'_pcl.txt"
     +      with dots'
            write(8,*) 'sand dgrid3d',nbx,',',nby
            write(8,*) 'sand hidden3d'
            write(8,*) 'sand pm3d'
            write(8,*) 'splot "'//basenm(1:lenbase)//'_pcw.txt"
     +      with dots'    
          close(unit=8)
          close(unit=9) 
       endif                                                              ! end of condition for creating contrib and sensit maps
          print*,'====================================================='
          print*,'          Total flux entering instrument (W)'
          write(*,2001) ftocap*real(vistep)+fctcld  
          print*,'              Sky radiance (W/str/m**2)'       
          write(*,2001) (ftocap+fctcld)/(lfente*
     +          longfe/focal**2.)/(pi*(diamobj/2.)**2.)*
     +          real(vistep)
       print*,'  '
       print*,' Interpolation flux error= ',
     +          ftocap-flcumu
       print*,'======================================================='
       write(2,*) '==================================================='
       write(2,*) '          Total flux entering instrument (W)'
       write(2,2001) ftocap*real(vistep)+fctcld
        write(2,*) '            Sky radiance (W/str/m**2)          '      
       write(2,2001) (ftocap+fctcld)/(lfente*
     +          longfe/focal**2.)/(pi*(diamobj/2.)**2.)*
     +          real(vistep)
       write(2,*) '  '                                                
       write(2,*) 'Interpolation flux errror= ',
     +          ftocap-flcumu
       write(2,*) '==================================================='
      close(2)
 2001 format('                   ',E10.3E2)
      stop
      end
c***********************************************************************************************************************
c*                                                                                                                     *
c*                                         end of the programme                                                            *
c*                                                                                                                     *
c***********************************************************************************************************************
