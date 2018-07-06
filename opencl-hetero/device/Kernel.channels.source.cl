// Waqar Nabi, Dec 5 2016
//

// include the custom header file generated for this run
#include "kernelCompilerInclude.h"
#define NTOT 1000
// -------------------------------
// Dealing with TYPES
// -------------------------------
//needed if we want to work with double
#if WORD==DOUBLE
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#endif

//If we are using floats or doubles, we use floating version of abs (fabs)
#if WORD==INT
 #define ABS abs
#else
 #define ABS fabs
#endif

// -------------------------------
// AOCL specific
// -------------------------------
#if TARGET==AOCL
#if NUM_COMPUTE_UNITS>1 
  __attribute__((num_compute_units(NUM_COMPUTE_UNITS)))
#endif
  
#if NUM_SIMD_ITEMS>1
  __attribute__((num_simd_work_items(NUM_SIMD_ITEMS)))
#endif
  
  //#ifdef REQ_WORKGROUP_SIZE
  //  __attribute__((reqd_work_group_size(REQ_WORKGROUP_SIZE)))
  //#endif
#endif

// -------------------------------
// SDACCEL specific
// -------------------------------
#if TARGET==SDACCEL
#endif    

// -------------------------------
// GENERIC attributes/opimizations
// -------------------------------
#ifdef REQ_WORKGROUPIZE
    __attribute__((reqd_work_group_size(REQ_WORKGROUP_SIZE)))
#endif


// -------------------------------
// SUB-KERNEL SIGNATURES
// -------------------------------
/*
void kernel_dyn( const stypeDevice dt
               , const stypeDevice dx
               , const stypeDevice dy
               , const stypeDevice g
               , __global stypeDevice * restrict eta
               , __global stypeDevice * restrict un
               , __global stypeDevice * restrict u
               , __global stypeDevice * restrict wet
               , __global stypeDevice * restrict v
               , __global stypeDevice * restrict vn
               , __global stypeDevice * restrict h
               , __global stypeDevice * restrict etan
               );

void kernel_shapiro  ( const stypeDevice eps 
                     , __global stypeDevice * restrict etan
                     , __global stypeDevice * restrict wet 
                     , __global stypeDevice * restrict eta
                     );

void kernel_updates ( __global stypeHost * restrict h 
                    , __global stypeHost * restrict hzero
                    , __global stypeHost * restrict eta
                    , __global stypeHost * restrict u
                    , __global stypeHost * restrict un
                    , __global stypeHost * restrict v
                    , __global stypeHost * restrict vn
                    , __global stypeHost * restrict wet
                    , stypeHost hmin
                    );
*/

// -------------------------------
// Channel declarations
// -------------------------------
channel stypeDevice  u_in_dyn
channel stypeDevice  v_in_dyn
channel stypeDevice  h_in_dyn
channel stypeDevice  eta_in_dyn
channel stypeDevice  wet_in_dyn

channel stypeDevice  u_out_update
channel stypeDevice  v_out_update
channel stypeDevice  h_out_update
channel stypeDevice  eta_out_update
channel stypeDevice  wet_out_update


// -------------------------------
// IO kernel
// -------------------------------
kernel void data_in (__global stypeDevice* u
                    ,__global stypeDevice* v
                    ,__global stypeDevice* h
                    ,__global stypeDevice* eta
                    ,__global stypeDevice* wet
) {
  int i,j;  

  for (j=1; j<= ROWS-2; j++) {
    for (k=1; k<= COLS-2; k++) {
      stypeDevice u_data  = u[j*COLS +k];
      stypeDevice v_data  = v[j*COLS + k];
      stypeDevice h_data  = h[j*COLS + k];
      stypeDevice eta_data= eta[j*COLS + k];
      stypeDevice wet_data= wet[j*COLS + k];
      //what about neighbours? Create a local buffer here?
      //OR
      //read separate STREAMS?
      //OR
      //do both?
      write_channel_altera(u_in_dyn   ,u_data   );
      write_channel_altera(v_in_dyn   ,v_data   );
      write_channel_altera(h_in_dyn   ,h_data   );
      write_channel_altera(eta_in_dyn ,eta_data );
      write_channel_altera(wet_in_dyn ,wet_data );
    }
  }
}//()


kernel void data_out  (__global stypeDevice* u
                      ,__global stypeDevice* v
                      ,__global stypeDevice* h
                      ,__global stypeDevice* eta
                      ,__global stypeDevice* wet
) {
  int i,j;  

  for (j=1; j<= ROWS-2; j++) {
    for (k=1; k<= COLS-2; k++) {
      stypeDevice u_new   = read_channel_altera(u_out_update);  
      stypeDevice v_new   = read_channel_altera(v_out_update);  
      stypeDevice h_new   = read_channel_altera(h_out_update);  
      stypeDevice eta_new = read_channel_altera(eta_out_update);  
      stypeDevice wet_new = read_channel_altera(wet_out_update);
    }
  }    
  
  
}//()

// -------------------------------
// SUPER KERNEL
// -------------------------------
//NOTE: currently this is DYN only    

__kernel void Kernel( const stypeDevice dt
                    , const stypeDevice dx
                    , const stypeDevice dy
                    , const stypeDevice g
                    , const stypeDevice eps
                    , const stypeDevice hmin
//                    , __global stypeDevice * restrict eta
//                    , __global stypeDevice * restrict un
//                    , __global stypeDevice * restrict u
//                    , __global stypeDevice * restrict wet
//                    , __global stypeDevice * restrict v
//                    , __global stypeDevice * restrict vn
//                    , __global stypeDevice * restrict h
//                    , __global stypeDevice * restrict etan
//                    , __global stypeDevice * restrict hzero
                    ) {
for (int i=0;i<NTOT;i++) {
kernel_dyn( dt
          , dx
          , dy
          , g
          , eta
          , un
          , u
          , wet
          , v
          , vn
          , h
          , etan
          );

kernel_shapiro  ( eps 
                , etan
                , wet 
                , eta
                );

kernel_updates ( h 
               , hzero
               , eta
               , u
               , un
               , v
               , vn
               , wet
               , hmin
               );
}
}//()

// -------------------------------
// DYN KERNEL
// -------------------------------
void kernel_dyn( const stypeDevice dt
               , const stypeDevice dx
               , const stypeDevice dy
               , const stypeDevice g
               , __global stypeDevice * restrict eta
               , __global stypeDevice * restrict un
               , __global stypeDevice * restrict u
               , __global stypeDevice * restrict wet
               , __global stypeDevice * restrict v
               , __global stypeDevice * restrict vn
               , __global stypeDevice * restrict h
               , __global stypeDevice * restrict etan
               ) {

 //locals
//-------------------
//__local stypeDevice du[ROWS][COLS];
//__local stypeDevice dv[ROWS][COLS];
//posix_memalign ((void**)&du, ALIGNMENT, SIZE*BytesPerWord);
//posix_memalign ((void**)&dv, ALIGNMENT, SIZE*BytesPerWord);
stypeDevice du;
stypeDevice dv;
stypeDevice uu;
stypeDevice vv;
stypeDevice duu;
stypeDevice dvv;
stypeDevice hue;
stypeDevice huw;
stypeDevice hwp;
stypeDevice hwn;
stypeDevice hen;
stypeDevice hep;
stypeDevice hvn;
stypeDevice hvs;
stypeDevice hsp;
stypeDevice hsn;
stypeDevice hnn;
stypeDevice hnp;
int j, k;


//loops for du, dv merged with loops for u and v
//that is why we no longer need local arrays du[] and dv[] for intermediat results (of duu and dvv)
//we just use duu and dvv directly as connecting scalars in this merged loops
  for (j=1; j<= ROWS-2; j++) {
    for (k=1; k<= COLS-2; k++) {
      //*(du + j*COLS + k)  = -dt 
      //du[j][k]  = -dt 
//calculate du, dv on all non-boundary points
//-------------------------------------------
      duu  = -dt 
           * g
           * ( eta[j*COLS + k+1]
             - eta[j*COLS + k  ]
             ) 
           / dx;
      //*(dv + j*COLS + k)  = -dt 
      //dv[j][k]  = -dt 
      dvv  = -dt 
           * g
           * ( eta[(j+1)*COLS + k]
             - eta[    j*COLS + k]
             ) 
           / dy;

//prediction for u and v (merged loop)
//---------------------------------
      un[j*COLS + k]  = 0.0;
      uu = u[j*COLS + k];
      if (  ( (wet[j*COLS + k] == 1)
              && ( (wet[j*COLS + k+1] == 1) || (duu > 0.0)))
         || ( (wet[j*COLS + k+1] == 1) && (duu < 0.0))     
         ){
          un[j*COLS + k] = uu+duu;
      }//if
      
      vn[j*COLS + k]  = 0.0;
      vv = v[j*COLS + k];
      if (  (  (wet[j*COLS + k] == 1)
             && ( (wet[(j+1)*COLS + k] == 1) || (dvv > 0.0)))
         || ((wet[(j+1)*COLS + k] == 1) && (dvv < 0.0))     
         ){
          vn[j*COLS + k] = vv+dvv;
      }//if

    }//for
  }//for

//sea level predictor
//--------------------
//TODO: Can I merge this loop? Note the use of stencil.. if I merge, then I will get stale values?
  for (j=1; j<= ROWS-2; j++) {
    for (k=1; k<= COLS-2; k++) {   
      hep = 0.5*( un[j*COLS + k] + ABS(un[j*COLS + k]) ) * h[j*COLS + k  ];
      hen = 0.5*( un[j*COLS + k] - ABS(un[j*COLS + k]) ) * h[j*COLS + k+1];
      hue = hep+hen;

      hwp = 0.5*( un[j*COLS + k-1] + ABS(un[j*COLS + k-1]) ) * h[j*COLS + k-1];
      hwn = 0.5*( un[j*COLS + k-1] - ABS(un[j*COLS + k-1]) ) * h[j*COLS + k  ];
      huw = hwp+hwn;

      hnp = 0.5*( vn[j*COLS + k] + ABS(vn[j*COLS + k]) ) * h[    j*COLS + k];
      hnn = 0.5*( vn[j*COLS + k] - ABS(vn[j*COLS + k]) ) * h[(j+1)*COLS + k];
      hvn = hnp+hnn;

      hsp = 0.5*( vn[(j-1)*COLS + k] + ABS(vn[(j-1)*COLS + k]) ) * h[(j-1)*COLS + k];
      hsn = 0.5*( vn[(j-1)*COLS + k] - ABS(vn[(j-1)*COLS + k]) ) * h[    j*COLS + k];
      hvs = hsp+hsn;

      etan[j*COLS + k]  = eta[j*COLS + k]
                        - dt*(hue-huw)/dx
                        - dt*(hvn-hvs)/dy;
    }//for
  }//for  

}//()



//------------------------------------------
// SHAPIRO KERNEL
//------------------------------------------
void kernel_shapiro     ( const stypeDevice eps 
                        , __global stypeDevice * restrict etan
                        , __global stypeDevice * restrict wet 
                        , __global stypeDevice * restrict eta
                        ) {

  //locals
  int j,k;
  stypeDevice term1,term2,term3;

  //1-order Shapiro filter
  for (j=1; j<= ROWS-2; j++) {
    for (k=1; k<= COLS-2; k++) {   
        if (wet[j*COLS + k]==1) {
        term1 = ( 1.0-0.25*eps
                  * ( wet[    j*COLS + k+1] 
                    + wet[    j*COLS + k-1] 
                    + wet[(j+1)*COLS + k  ] 
                    + wet[(j-1)*COLS + k  ] 
                    ) 
                )
                * etan[j*COLS + k]; 
        term2 = 0.25*eps
                * ( wet [j*COLS + k+1]
                  * etan[j*COLS + k+1]
                  + wet [j*COLS + k-1]
                  * etan[j*COLS + k-1]
                  );
        term3 = 0.25*eps
                * ( wet [(j+1)*COLS + k]
                  * etan[(j+1)*COLS + k]
                  + wet [(j-1)*COLS + k]
                  * etan[(j-1)*COLS + k]
                  );
        eta[j*COLS + k] = term1 + term2 + term3;
      }//if
      else {
        eta[j*COLS + k] = etan[j*COLS + k];
      }//else
    }//for
  }//for
}//()


//------------------------------------------
// UPDATES KERNEL
//------------------------------------------
void kernel_updates ( __global stypeHost * restrict h 
                    , __global stypeHost * restrict hzero
                    , __global stypeHost * restrict eta
                    , __global stypeHost * restrict u
                    , __global stypeHost * restrict un
                    , __global stypeHost * restrict v
                    , __global stypeHost * restrict vn
                    , __global stypeHost * restrict wet
                    , stypeHost hmin
                    ) {

  for (int j=0; j<= ROWS-1; j++) {
    for (int k=0; k<=COLS-1; k++) {
      //h update
      h[j*COLS + k] = hzero[j*COLS + k] 
                    + eta  [j*COLS + k];
      //wet update
      wet[j*COLS + k] = 1;
      if ( h[j*COLS + k] < hmin )
            wet[j*COLS + k] = 0;
      //u, v updates
      u[j*COLS + k] = un[j*COLS + k];
      v[j*COLS + k] = vn[j*COLS + k];
    }//for
  }//for
}//()
