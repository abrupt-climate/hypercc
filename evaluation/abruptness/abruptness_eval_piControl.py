##### Script to assess the performance of the abruptness measure used in hypercc

# The whole script is only for test cases with noise from complex climate model:
# Instead of generating artificial noise, temperature time series from piControl are used
#, combined with the typical artificial step changes.
# model used: MPI-ESM-LR

import numpy as np
import matplotlib.pyplot as plt
from abruptness_definition import compute_abruptness
import netCDF4

#testcase_vec=[5, 6, 11, 12, 13, 14]   
#cutoff_length_vec=[0, 2, 4, 6, 8]
#chunk_max_length_vec=[30]


testcase_vec=[15, 16]   
cutoff_length_vec=[1, 4, 6]
chunk_max_length_vec=[30]


#testcase_vec=[5, 6, 11, 12, 13, 14, 15, 16]
## running
#testcase_vec=[11, 13, 14]
#cutoff_length_vec=[1, 2, 4, 6]
#chunk_max_length_vec=[30]


#cutoff_length_vec=[2]
#chunk_max_length_vec=[100]


chunk_min_length=0

nofsteps=11
stepsize_ini=0
stepsize_fin=10
noiselevel=1


### Do not change: 
N=200
nrea_x=96*5  # 96 latitudes and 5 time chunks lumped into one dimension
nrea_y=192   #longitude (in the original file)


for testcase in testcase_vec:
    plot_ts=1
    ## parameter settings for definition of abruptness
    for cutoff_length in cutoff_length_vec:
        for chunk_max_length in chunk_max_length_vec:
  
            ## For practical reasons, realisations are distributed
            ## over a rectangular grid (like spatial points in a climate model)
            ## "spatial" dimensions: nrea_x/y
            ## time dimension is the first dimension (index label in python: 0)

            if chunk_max_length == 30:
                a_max=18
            elif chunk_max_length == 100:
                a_max=13

            jumptime=int(chunk_max_length+cutoff_length+1)

            if testcase == 5:   ## red noise, with trend              
                slope=0

            elif testcase == 6:
                slope=10

            elif testcase == 11:
                slope=0
                tau=2

            elif testcase == 12:
                slope=10
                tau=2

            elif testcase == 13:
                slope=0
                tau=5

            elif testcase == 14:
                slope=10
                tau=5

            elif testcase == 15:
                slope=0
                jumptime=20

            elif testcase == 16:
                slope=0
                jumptime=10

            # for abruptness quantification, need time axis.
            years=np.arange(1,N+1)
                        
            abruptness_out=np.zeros((nrea_x*nrea_y, nofsteps))
                  
            ## create mask with the edges (including the 0-sized "edge")
            mask=np.zeros((N,nrea_x,nrea_y),dtype=bool)
            mask[round(jumptime),:,:]=1
 
            # initialise matrix with background variability
            piC=np.zeros((N,nrea_x,nrea_y))
            
            ## read in the "noise" from piControl simulation           
            ncfile1 = netCDF4.Dataset("tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk1.nc", "r", format="NETCDF4")
            tas1 = ncfile1.variables['tas'][:,:,:]
            ncfile2 = netCDF4.Dataset("tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk2.nc", "r", format="NETCDF4")
            tas2 = ncfile2.variables['tas'][:,:,:]
            ncfile3 = netCDF4.Dataset("tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk3.nc", "r", format="NETCDF4")
            tas3 = ncfile3.variables['tas'][:,:,:]
            ncfile4 = netCDF4.Dataset("tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk4.nc", "r", format="NETCDF4")
            tas4 = ncfile4.variables['tas'][:,:,:]
            ncfile5 = netCDF4.Dataset("tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk5.nc", "r", format="NETCDF4")
            tas5 = ncfile5.variables['tas'][:,:,:]

            ## reshape it: add the chunks to the latitude dimension instead of time
            ## here, always use the full 200 years of each chunk because we want to normalise the variability with
            # as much data we have, and not just the sample used for the abruptness quantification
            piC[:,0:96,:]=tas1
            piC[:,96:2*96,:]=tas2
            piC[:,2*96:3*96,:]=tas3
            piC[:,3*96:4*96,:]=tas4
            piC[:,4*96:5*96,:]=tas5
 

            ## normalise variability to 1 for each realisation (but keep spectrum):
            piCstd=np.std(piC, axis=0)
            piCmean=np.mean(piC, axis=0)

            for x in range(nrea_x):
                for y in range(nrea_y):
                    piC[:,x,y]=piC[:,x,y]-piCmean[x,y]
                    piC[:,x,y]=piC[:,x,y]/piCstd[x,y]
 
            ## loop over step sizes
            stepvec=np.linspace(stepsize_ini,stepsize_fin,nofsteps)
            for stepind in range(len(stepvec)):
                
                step=stepvec[stepind]
                
                ## generate the time series
                
                ts=np.zeros((N,nrea_x,nrea_y))
                
                for timeind in years:

                    if testcase < 11 or testcase > 14:
                        if timeind < jumptime:
                            mu = slope/N*(timeind-1)
                        else:
                            mu = step + slope/N*(timeind-1)

                    else:
                        if timeind < jumptime-tau:
                            mu = slope/N*(timeind-1)
                        elif timeind > jumptime+tau:
                            mu = step + slope/N*(timeind-1)
                        else:
                            t_start=jumptime-tau-1
                            t_end=jumptime+tau+1
                            mu_start = slope/N*(t_start-1)
                            mu_end = step + slope/N*(t_end-1)
                            newslope = (mu_end-mu_start)/(t_end-t_start)
                            mu = mu_start + newslope*(timeind-t_start)

                    ts[timeind-1,:,:]=noiselevel*piC[timeind-1,:,:]+mu
         

                #### plot one example
                if ( step == 3 and plot_ts == 1 ):   
                    fig = plt.figure()
                    ax=plt.subplot(111)

                    Nplot=jumptime+chunk_max_length+cutoff_length+2

                    #print(jumptime)
                    #print(chunk_max_length)
                    #print(cutoff_length)

                    ax.plot(years[0:Nplot],ts[0:Nplot,0,0],'-k')
                    ax.set_xlabel('time', fontsize=20)
                    ax.set_ylabel('data', fontsize=20)
                    fig.suptitle('testcase'+str(testcase)+', step size 3')
                    fig.savefig('testcase'+str(testcase)+'_ts.png', bbox_inches='tight')
                    plot_ts=0       
                    quit()
                    
                
                ### measure the abruptness at the transition point
                abruptness_results=compute_abruptness(mask, years, ts, cutoff_length, chunk_max_length, chunk_min_length)
                abruptness    = abruptness_results['abruptness']
                
                abruptness_out[:,stepind]=np.reshape(abruptness,nrea_x*nrea_y)
            
                        
            
            # plot results
            
            fig = plt.figure()
            ax=plt.subplot(111)
            plt.boxplot(abruptness_out)
            
            ax.set_xticklabels(stepvec.astype(int))
            
            ax.set_xlabel('step size', fontsize=20)
            ax.set_ylabel('abruptness', fontsize=20)
            ax.set_ylim([0,a_max])
            fig.suptitle('testcase'+str(testcase)+', chunk_max_length='+str(chunk_max_length)+', cutoff_length='+str(cutoff_length))
            
            fig.savefig('testcase'+str(testcase)+'_chunk_max_length'+str(chunk_max_length)+'_cutoff_length'+str(cutoff_length)+'_abruptness_distribution.png', bbox_inches='tight')
            

