"""
Calibration of space-time fractions.
"""

import numpy as np
from .stats import weighted_quartiles
from .filters import sobel_filter


def calibrate_sobel(config, box, data, delta_t, delta_d):
    """Calibrate the weights of the Sobel operator.

    :param box: Box instance
    :param data: ndarray or masked array with shape equal to box.shape
    :param delta_t: start value for delta_t
    :param delta_d: start value for delta_d
    :return: dictionary with statistical information about data
    """

    ## Some variables can be 0 (e.g. SW fluxes in polar winter).
    ## Add tiny noise to prevent calibration from failing because of that
    #randn(shape(smooth_control_data))  ## this line fails, hence explicit for each dim:
    quartile = ['min', '1st', 'median', '3rd', 'max'] \
        .index(config.calibration_quartile)

    len1=np.size(data, axis=0)
    len2=np.size(data, axis=1)
    len3=np.size(data, axis=2)
    random_matrix=np.random.randn(len1,len2,len3)*1e-25
    noise=np.where(abs(data)<1e-25,random_matrix,0)
    data=data+noise

    sbc = sobel_filter(box, data, weight=[delta_t, delta_d, delta_d])
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

    ft = weighted_quartiles(var_t, weights)
    fx = weighted_quartiles(var_x, weights)

    gamma = np.sqrt(ft / fx)
    var_x *= gamma[quartile]
    fm = weighted_quartiles(var_x**2 + var_t**2, weights)

    return {
        'time': np.sqrt(ft),
        'distance': np.sqrt(fx),
        'magnitude': np.sqrt(fm),
        'gamma': gamma
    }
