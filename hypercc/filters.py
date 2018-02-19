"""
Implements different filters on spherical grid.
"""

import sys

import numpy as np
from scipy import ndimage


def gaussian_filter_2d(box, data, sigma_lat, sigma_lon):
    """Filters a 2D (lat x lon) data set with a Gaussian, correcting for
    the distortion from the geographic projection.

    :param box: instance of :py:class:`Box`.
    :param data: data set, dimensions should match ``box.shape``.
    :param sigma_lat: sigma lat in dimension of distance (e.g. km).
    :param sigma_lon: sigma lon in dimension of distance (e.g. km).
    :return: :py:class:`numpy.ndarray` with the same shape as input.
    """
    res_lat, res_lon = box.resolution
    s_lat = (sigma_lat / res_lat).m_as('')
    s_lon = (sigma_lon / res_lon).m_as('')

    outp = np.zeros_like(data)

    for i, lat_rad in enumerate(box.lat / 180 * np.pi):
        ndimage.gaussian_filter(
            data[i, :],
            min(data.shape[1], s_lon / np.cos(lat_rad)),
            mode=['wrap'],
            output=outp[i, :])

    ndimage.gaussian_filter(
        outp, [s_lat, 0.0], mode=['constant', 'wrap'], output=outp)

    return outp


def gaussian_filter_3d(box, data, sigma_t, sigma_lat, sigma_lon):
    """Filters a 3D (time x lat x lon) data set with a Gaussian, correcting for
    the distortion from the geographic projection.

    :param box: instance of :py:class:`Box`.
    :param data: data set, dimensions should match ``box.shape``.
    :param sigma_t: sigma time in dimension of time (e.g. year).
    :param sigma_lat: sigma lat in dimension of distance (e.g. km).
    :param sigma_lon: sigma lon in dimension of distance (e.g. km).
    :return: :py:class:`numpy.ndarray` with the same shape as input.
    """
    res_t, res_lat, res_lon = box.resolution
    s_t = (sigma_t / res_t).m_as('')
    s_lat = (sigma_lat / res_lat).m_as('')
    s_lon = (sigma_lon / res_lon).m_as('')

    outp = np.zeros_like(data)
    for i, lat_rad in enumerate(box.lat_bnds.mean(axis=1) / 180 * np.pi):
        ndimage.gaussian_filter(
            data[:, i, :],
            min(data.shape[2], s_lon / np.cos(lat_rad)),
            mode=['reflect', 'wrap'],
            output=outp[:, i, :])

    ndimage.gaussian_filter(
        outp, [s_t, s_lat, 0.0], mode=['reflect', 'reflect', 'wrap'],
        output=outp)

    return outp


def sobel_filter_2d(box, data, weight=None, physical=True):
    """Sobel filter in 2D (lat x lon). Effectively computes a derivative.
    This filter is normalised to return a rate of change per pixel, or
    if weights are given, the value is multiplied by the weight to obtain
    a unitless quantity of change over the given weight.

    :param box: :py:class:`Box` instance
    :param data: input data, :py:class:`numpy.ndarray` with same shape
        as ``box.shape``.
    :param weight: weight of each dimension in combining components into
        a vector magnitude; should have units corresponding those given
        by ``box.resolution``.
    :param physical: wether to correct for geometric projection, by dividing
        the derivative in the longitudinal direction by the cosine of the
        latitude."""
    if weight is None:
        weight = [1/8, 1/8]
    else:
        weight = [(1/8 * w / r).m_as('')
                  for w, r in zip(weight, box.resolution)]

    result = np.array([
        ndimage.sobel(data, mode=['reflect', 'wrap'], axis=i) * weight[i]
        for i in range(2)])

    if physical:
        result[1, :, :] /= np.cos(box.lat / 180 * np.pi)[:, None]

    result = np.r_[result, np.ones_like(result[0:1])]
    norm = np.sqrt((result[:-1]**2).sum(axis=0))
    result /= norm
    return result


def sobel_filter_3d(box, data, weight=None, physical=True, variability=None):
    """Sobel filter in 3D (time x lat x lon). Effectively computes a
    derivative.  This filter is normalised to return a rate of change per
    pixel, or if weights are given, the value is multiplied by the weight to
    obtain a unitless quantity of change over the given weight.

    :param box: :py:class:`Box` instance
    :param data: input data, :py:class:`numpy.ndarray` with same shape
        as ``box.shape``.
    :param weight: weight of each dimension in combining components into
        a vector magnitude; should have units corresponding those given
        by ``box.resolution``.
    :param physical: wether to correct for geometric projection, by dividing
        the derivative in the longitudinal direction by the cosine of the
        latitude."""
    if weight is None:
        weight = [1/16, 1/16, 1/16]
    else:
        weight = [(1/16 * w / r).m_as('')
                  for w, r in zip(weight, box.resolution)]

    result = np.array([
        ndimage.sobel(
            data, mode=['reflect', 'reflect', 'wrap'], axis=i) * weight[i]
        for i in range(3)])

    if variability is not None:
        for i in range(3):
            result[i] /= variability[i]

    if physical:
        factor = np.cos(box.lat_bnds.mean(axis=1) / 180 * np.pi)[None, :, None]
        result[2, :, :, :] /= factor

    result = np.r_[result, np.ones_like(result[0:1])]
    norm = np.sqrt((result[:-1]**2).sum(axis=0))
    with np.errstate(divide='ignore', invalid='ignore'):
        result /= norm
    return result


def sobel_filter_3d_masked(
        box, masked_data, weight=None, physical=True, variability=None):
    """Compute sobel filter on masked array. The mask is diluted by one pixel
    afterwards."""
    sb_data = sobel_filter_3d(
        box, masked_data.data, weight, physical, variability)
    # new_mask = ndimage.binary_dilation(
    #     masked_data.mask, ndimage.generate_binary_structure(3, 3),
    #     iterations=1)
    return np.ma.MaskedArray(
        sb_data, np.repeat(masked_data.mask[None, :, :, :], 4, axis=0))


def taper_masked_area(data, size, n_steps):
    """Iteratively bleed values from valid regions into the masked area using
    a uniform filter. This should limit boundary effects when filtering later
    on. The masked area is zeroed before running. Output is written back to the
    original data."""
    if not isinstance(data, np.ma.core.MaskedArray):
        raise TypeError("Expected a masked array.")

    if data.mask is np.ma.nomask:
        print("Mask is empty, not doing anything.", file=sys.stderr)

    data.data[data.mask] = 0.0
    for _ in range(n_steps):
        temp = ndimage.uniform_filter(data.data, size, mode='wrap')
        data.data[data.mask] = temp[data.mask]


def gaussian_filter(box, data, sigma):
    """Filters a data set with a Gaussian, correcting for the distortion
    from the geographic projection.

    :param box: instance of :py:class:`Box`.
    :param data: data set, dimensions should match ``box.shape``.
    :param sigma: list of sigmas with the correct dimension.
    :return: :py:class:`numpy.ndarray` with the same shape as input.
    """
    if isinstance(box.time, np.ndarray):
        return gaussian_filter_3d(box, data, *sigma)
    else:
        return gaussian_filter_2d(box, data, *sigma)


def sobel_filter(box, data, weight=None, physical=True, variability=None):
    """Sobel filter. Effectively computes a derivative.  This filter is
    normalised to return a rate of change per pixel, or if weights are
    given, the value is multiplied by the weight to obtain a unitless
    quantity of change over the given weight.

    :param box: :py:class:`Box` instance
    :param data: input data, :py:class:`numpy.ndarray` with same shape
        as ``box.shape``.
    :param weight: weight of each dimension in combining components into
        a vector magnitude; should have units corresponding those given
        by ``box.resolution``."""
    if not isinstance(box.time, np.ndarray):
        return sobel_filter_2d(box, data, weight, physical)
    elif isinstance(data, np.ma.core.MaskedArray) and \
            data.mask is not np.ma.nomask:
        return sobel_filter_3d_masked(box, data, weight, physical, variability)
    else:
        return sobel_filter_3d(box, data, weight, physical, variability)
