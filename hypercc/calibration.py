"""
Calibration of space-time fractions.
"""

import numpy as np
from .stats import weighted_quartiles
from .filters import sobel_filter


def calibrate_sobel(quartile, box, data, delta_t, delta_d):
    """Calibrate the weights of the Sobel operator.

    :param box: Box instance
    :param data: ndarray or masked array with shape equal to box.shape
    :param delta_t: start value for delta_t
    :param delta_d: start value for delta_d
    :return: dictionary with statistical information about data
    """

    ## Some variables can be 0 (e.g. SW fluxes in polar winter).
    ## Add tiny noise to prevent calibration from failing because of that
    ##randn(shape(smooth_control_data))  ## this line fails, hence explicit for each dim:
    #len1=np.size(data, axis=0)
    #len2=np.size(data, axis=1)
    #len3=np.size(data, axis=2)
    #noiselevel=1e-25
    #random_matrix=np.random.randn(len1,len2,len3)*noiselevel
    #noise=np.where(abs(data)<noiselevel,random_matrix,0)
    #data=data+noise
    ##

    ## problem: don't know how large the noise should be (should not affect the data!). 

    # => accept that sobel cannot handle this and fix the output below

    sbc = sobel_filter(box, data, weight=[delta_t, delta_d, delta_d])

    ## check indices with nans
    #indices_0=np.argwhere(np.isnan(sbc[0]))
    #indices_1=np.argwhere(np.isnan(sbc[1]))
    #indices_2=np.argwhere(np.isnan(sbc[2]))
    #indices_3=np.argwhere(np.isnan(sbc[3]))
    #indices_nans=np.argwhere(np.isnan(sbc))
    #if size(indices_0) + size(indices_1) + size(indices_2) + size(indices_3) > 0:
    #print(np.size(indices_nans))
    #if np.size(indices_nans) > 0:
   #	print('Warning: Sobel filter yields nans! Number of cases per dimension:')
   # 	print(np.shape(indices_nans))
   # 	print(np.size(indices_0))
   # 	print(np.size(indices_1))
   # 	print(np.size(indices_2))
   #  	print(np.size(indices_3))
   # 	print('total shape of sbc:')
   # 	print(np.shape(sbc))
   # 	nans_all=np.isnan(sbc).sum()
   # 	nans_0=np.isnan(sbc[0]).sum()
   # 	print(nans_all)
   # 	print(size
    	#print(nans_0)
    	#print(indices_1)
    	#print(indices_2)
    	#print(indices_3)

    gradients=sbc[0:2]
    nancount=np.isnan(gradients).sum()
    if nancount > 0:
        print(' ')
        print('Warning: Sobel filter yields nans!')
        totalsize=np.size(gradients)
        nanratio=nancount / totalsize * 100
        print('nans per total size in %:', nanratio)
        print(' ')


    if isinstance(data, np.ma.core.MaskedArray) \
            and (data.mask is not np.ma.nomask):
        var_t = (sbc[0]**2 / sbc[3]**2).compressed()
        var_x = ((sbc[1]**2 + sbc[2]**2) / sbc[3]**2).compressed()
        var_m = (1.0 / sbc[3]).compressed()
        weights = np.repeat(
            box.relative_grid_area[None, :, :],
            box.shape[0], axis=0)[~data.mask].flatten()
    else:
        var_t = (sbc[0]**2 / sbc[3]**2).flatten()
        var_x = ((sbc[1]**2 + sbc[2]**2) / sbc[3]**2).flatten()
        var_m = (1.0 / sbc[3]).flatten()
        weights = np.repeat(
            box.relative_grid_area[None, :, :],
            box.shape[0], axis=0).flatten()


    ###Sebastian: Ignore the nans when calculating the distributions
    ##var_t_nonans = np.ma.masked_array(var_t, np.isnan(var_t))
    ##var_x_nonans = np.ma.masked_array(var_x, np.isnan(var_x))
    var_t_nonans = var_t[~np.isnan(var_t)]
    var_x_nonans = var_x[~np.isnan(var_t)]
    var_t_nonans = var_t[~np.isnan(var_x)]
    var_x_nonans = var_x[~np.isnan(var_x)]

    ft = weighted_quartiles(var_t_nonans, weights)
    fx = weighted_quartiles(var_x_nonans, weights)

    gamma = np.sqrt(ft / fx)
    var_x_nonans *= gamma[quartile]
    fm = weighted_quartiles(var_x_nonans**2 + var_t_nonans**2, weights)
    ###


    # problem: there can be nans in var_t and var_x !
    # reason: sbc indices 0-2 have nans - index 3 not. 
    #print(var_t)
    #print(var_x)
    #print(np.min(var_t))
    #print(np.min(var_x))
    #print(np.max(var_t))
    #print(np.max(var_x))
    #indices_t=np.argwhere(np.isnan(var_t))
    #indices_x=np.argwhere(np.isnan(var_x))
    #print(indices_t)
    #print(indices_x)
    #print(np.min(sbc[0]))
    #print(np.min(sbc[1]))
    #print(np.min(sbc[2]))
    #print(np.min(sbc[3]))
    #print(np.min(var_t_nonans))
    #print(np.max(var_t_nonans))
    #print(np.min(var_x_nonans))
    #print(np.max(var_x_nonans))



    ### old:
    #ft = weighted_quartiles(var_t, weights)
    #fx = weighted_quartiles(var_x, weights)

    #gamma = np.sqrt(ft / fx)
    #var_x *= gamma[quartile]
    #fm = weighted_quartiles(var_x**2 + var_t**2, weights)



    return {
        'time': np.sqrt(ft),
        'distance': np.sqrt(fx),
        'magnitude': np.sqrt(fm),
        'gamma': gamma
    }
