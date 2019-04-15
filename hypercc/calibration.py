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
    sbc = sobel_filter(box, data, weight=[delta_t, delta_d, delta_d])


    gradients=sbc[0:2]
    nancount=np.isnan(gradients).sum()
    if nancount > 0:
        print(' ')
        print('Warning: Sobel filter yields nans!')
        totalsize=np.size(gradients)
        nanratio=nancount / totalsize * 100
        print('nans per total size in %:', nanratio)
        print(' ')

   
    
    #sbc=np.longdouble(sbc)   # higher precision to avoid overflow
    
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


    ###Ignore nans when calculating the distributions
    var_t_nonans = var_t[~np.isnan(var_t)]
    var_x_nonans = var_x[~np.isnan(var_t)]
    var_t_nonans = var_t[~np.isnan(var_x)]
    var_x_nonans = var_x[~np.isnan(var_x)]

    ft = weighted_quartiles(var_t_nonans, weights)
    fx = weighted_quartiles(var_x_nonans, weights)

    fx[fx==0] = np.nan
    gamma = np.sqrt(ft / fx)
    

    var_x_nonans *= gamma[quartile]
    fm = weighted_quartiles(var_x_nonans**2 + var_t_nonans**2, weights)

    return {
        'time': np.sqrt(ft),
        'distance': np.sqrt(fx),
        'magnitude': np.sqrt(fm),
        'gamma': gamma
    }
