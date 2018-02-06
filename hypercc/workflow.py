"""
Implements the HyperCanny workflow for climate data.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import noodles

from hyper_canny import cp_edge_thinning, cp_double_threshold

from .data.data_set import DataSet
from .units import unit, month_index
from .filters import gaussian_filter, sobel_filter
from .calibration import calibrate_sobel
from .plotting import plot_signal_histogram, plot_plate_carree


def open_data_files(config):
    """Open data files from the settings given in `config`.

    :param config: namespace object (as returned by argparser)
    :return: DataSet
    """
    month = month_index(config.month)

    data_set = DataSet(
        path=config.data_folder,
        model=config.model,
        variable=config.variable,
        scenario=config.scenario,
        realization=config.realization,
        extension=config.extension
    )

    return data_set[month::12]


def open_pi_control(config):
    month = month_index(config.month)

    control_set = DataSet(
        path=config.data_folder,
        model=config.model,
        variable=config.variable,
        scenario='piControl',
        realization=config.realization)

    return control_set[month::12]


@noodles.schedule(store=True, call_by_ref=['data_set'])
def compute_calibration(config, data_set):
    month = month_index(config.month)

    sigma_t, sigma_x = get_sigmas(config)
    sobel_scale = float(config.sobel_scale[0]) * unit(config.sobel_scale[1])
    sobel_delta_t = 1.0 * unit.year
    sobel_delta_x = sobel_delta_t * sobel_scale

    data = data_set.data[month::12]
    box = data_set.box[month::12]

    smooth_data = noodles.schedule(gaussian_filter)(
        box, data, [sigma_t, sigma_x, sigma_x])
    calibration = noodles.schedule(calibrate_sobel)(
        box, smooth_data, sobel_delta_t, sobel_delta_x)

    return calibration


@noodles.schedule
def get_calibration_factor(config, calibration):
    return calibration['gamma'][3]


def get_sigmas(config):
    sigma_t = float(config.sigma_t[0]) * unit(config.sigma_t[1])
    sigma_x = float(config.sigma_x[0]) * unit(config.sigma_x[1])
    return sigma_t, sigma_x


def get_sobel_weights(config, calibration):
    sobel_scale = float(config.sobel_scale[0]) * unit(config.sobel_scale[1])
    gamma = calibration['gamma'][3]
    sobel_delta_t = 1.0 * unit.year
    sobel_delta_x = sobel_delta_t * sobel_scale * gamma
    return [sobel_delta_t, sobel_delta_x, sobel_delta_x]


@noodles.schedule(store=True)
def generate_signal_plot(config, box, sobel_data, title, filename):
    fig = plot_signal_histogram(box, 1 / sobel_data[3])
    fig.suptitle(title)
    fig.savefig(filename)
    return Path(filename)


def maximum_suppression(sobel_data):
    mask = cp_edge_thinning(sobel_data.transpose([3, 2, 1, 0]))
    return mask.transpose([2, 1, 0])


def hysteresis_thresholding(config, sobel_data, mask, calibration):
    lower = calibration['magnitude'][3]
    upper = calibration['magnitude'][4]
    new_mask = cp_double_threshold(
        sobel_data.transpose([3, 2, 1, 0]),
        mask.transpose([2, 1, 0]),
        1. / upper,
        1. / lower)
    return new_mask.transpose([2, 1, 0])


@noodles.schedule(store=True, call_by_ref=['data_set'])
def compute_canny_edges(config, data_set, calibration):
    data = data_set.data
    box = data_set.box

    sigma_t, sigma_x = get_sigmas(config)
    weights = get_sobel_weights(config, calibration)

    smooth_data = noodles.schedule(gaussian_filter)(
        box, data, [sigma_t, sigma_x, sigma_x])
    sobel_data = noodles.schedule(sobel_filter)(
        box, smooth_data, weight=weights)
    pixel_sobel = noodles.schedule(sobel_filter)(
        box, smooth_data, physical=False)
    sobel_maxima = noodles.schedule(maximum_suppression)(pixel_sobel)

    edges = noodles.schedule(hysteresis_thresholding)(
        config, sobel_data, sobel_maxima, calibration)

    return noodles.gather_dict(
        sobel=sobel_data,
        edges=edges)


def generate_report(config):
    control_set = open_pi_control(config)
    calibration = compute_calibration(config, control_set)

    data_set = open_data_files(config)
    canny_edges = compute_canny_edges(config, data_set, calibration)

    signal_plot = generate_signal_plot(
        config, data_set.box, canny_edges['sobel'], "signal", "signal.svg")

    return noodles.lift({
        'calibration': calibration,
        'sobel': noodles.schedule(lambda x: list(x))(canny_edges.keys()),
        'signal_plot': signal_plot
    })
