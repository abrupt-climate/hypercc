##### Script to assess the performance of the abruptness measure used in hypercc

### testcases for stochastic noise

import numpy as np
import matplotlib.pyplot as plt
from abruptness_definition import compute_abruptness

testcase_vec=[1, 2, 7, 8, 9, 10]
cutoff_length_vec=[0, 2, 4, 6, 8]
chunk_max_length_vec=[30]   


testcase_vec=[1, 2, 7, 8, 9, 10]
cutoff_length_vec=[0, 2, 4]
chunk_max_length_vec=[100]


testcase_vec=[11, 12]
cutoff_length_vec=[2] #, 2, 4, 6, 8]
chunk_max_length_vec=[30, 100]


testcase_vec=[1, 2]
cutoff_length_vec=[1, 2, 4, 6]
chunk_max_length_vec=[30]


chunk_min_length=0

## For practical reasons, realisations are distributed
## over a rectangular grid (like spatial points in a climate model)
## "spatial" dimensions: nrea_x,y
## time dimension is the first dimension (index label in python: 0)
nrea_x=96*5
nrea_y=192
nofsteps=11
stepsize_ini=0
stepsize_fin=10

for testcase in testcase_vec:
    plot_ts=1
    ## parameter settings for definition of abruptness
    for cutoff_length in cutoff_length_vec:
        for chunk_max_length in chunk_max_length_vec:
               
            if chunk_max_length == 30:
                a_max=18
            elif chunk_max_length == 100:
                a_max=13

            N=2*(chunk_max_length+cutoff_length)+2
            jumptime=N/2

            if testcase == 1:     ## white noise, no trend
                slope=0 
                c=0
                noiselevel=1
            
            elif testcase == 2:     ## white noise, with trend
                slope=10
                c=0
                noiselevel=1
            
            elif testcase == 3:   ## red noise, no trend
                slope=0
                c=0.8
                noiselevel=np.sqrt(1-c**2)
            
            elif testcase == 4:   ## red noise, with trend
                slope=10
                c=0.8
                noiselevel=np.sqrt(1-c**2)

            elif testcase == 7:
                slope=0
                c=0
                noiselevel=1
                tau=5

            elif testcase == 8:
                slope=0
                c=0
                noiselevel=1
                tau=2

            elif testcase == 9:
                slope=10
                c=0
                noiselevel=1
                tau=5

            elif testcase == 10:
                slope=10
                c=0
                noiselevel=1
                tau=2

            elif testcase == 11:
                slope=0
                c=0
                noiselevel=1
                jumptime=20

            elif testcase == 12:
                slope=0
                c=0
                noiselevel=1
                jumptime=10

            
            # for abruptness quantification, need time axis.
            years=np.arange(1,N+1)
            
            
            abruptness_out=np.zeros((nrea_x*nrea_y, nofsteps))
            
            
            ## create mask with the edges (including the 0-sized "edge")
            mask=np.zeros((N,nrea_x,nrea_y),dtype=bool)
            mask[round(jumptime),:,:]=1
            
            
            ## loop over step sizes
            stepvec=np.linspace(stepsize_ini,stepsize_fin,nofsteps)
            for stepind in range(len(stepvec)):
                
                step=stepvec[stepind]
                
                
                ## generate the time series
                
                ts=np.zeros((N,nrea_x,nrea_y))
                
                for timeind in years:

                    ## step change:
                    if testcase < 5 or testcase > 10:
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


                    if timeind == 1:
                        ts[0,:,:]=noiselevel*np.random.randn(nrea_x,nrea_y)+mu
                    else:
                        ts[timeind-1,:,:]=noiselevel*np.random.randn(nrea_x,nrea_y)+mu+c*(ts[timeind-2]-mu)
                
                
                #### plot one example
                if ( step == 3 and plot_ts == 1 ):   
                    fig = plt.figure()
                    ax=plt.subplot(111)
                    ax.plot(years,ts[:,0,0],'-k')
                    ax.set_xlabel('time', fontsize=20)
                    ax.set_ylabel('data', fontsize=20)
                    fig.suptitle('testcase'+str(testcase)+', step size 3')
                    fig.savefig('testcase'+str(testcase)+'_ts.png', bbox_inches='tight')
                    plot_ts=0       
                    
                
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
            

