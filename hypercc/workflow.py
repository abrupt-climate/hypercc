"""
Implements the HyperCanny workflow for climate data.
"""

import noodles
from .data.data_set import DataSet
from .units import unit, month_index
from .filters import gaussian_filter
from .calibration import calibrate_sobel


def open_data_files(config):
    """Open data files from the settings given in `config`.

    :param config: namespace object (as returned by argparser)
    :return: DataSet
    """
    data_set = DataSet(
        path=config.data_folder,
        model=config.model,
        variable=config.variable,
        scenario=config.scenario,
        realization=config.realization,
        extension=config.extension
    )

    return data_set


def open_pi_control(config):
    control_set = DataSet(
        path=config.data_folder,
        model=config.model,
        variable=config.variable,
        scenario='piControl',
        realization=config.realization)

    return control_set


@noodles.schedule
def compute_calibration(config, data_set):
    data_set = data_set.unref()

    month = month_index(config.month)
    assert isinstance(month, int)
    assert 0 <= month <= 12

    sigma_t = float(config.sigma_t[0]) * unit(config.sigma_t[1])
    sigma_x = float(config.sigma_x[0]) * unit(config.sigma_x[1])
    sobel_scale = float(config.sobel_scale[0]) * unit(config.sobel_scale[1])
    sobel_delta_t = 1.0 * unit.year
    sobel_delta_x = sobel_delta_t * sobel_scale

    data = data_set.data[month::12]
    box = data_set.box[month::12]

    smooth_data = gaussian_filter(
        box, data, [sigma_t, sigma_x, sigma_x])
    calibration = calibrate_sobel(
        box, smooth_data, sobel_delta_t, sobel_delta_x)

    return calibration


def generate_report(config):
    control_set = open_pi_control(config)
    return compute_calibration(config, noodles.ref(control_set))
