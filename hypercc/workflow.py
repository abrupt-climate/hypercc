"""
Implements the HyperCanny workflow for climate data.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy import ndimage
import noodles

from hyper_canny import cp_edge_thinning, cp_double_threshold

from .data.data_set import DataSet
from .units import unit, month_index
from .filters import gaussian_filter, sobel_filter, taper_masked_area
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
    sigma_t, sigma_x = get_sigmas(config)
    sobel_scale = float(config.sobel_scale[0]) * unit(config.sobel_scale[1])
    sobel_delta_t = 1.0 * unit.year
    sobel_delta_x = sobel_delta_t * sobel_scale

    data = data_set.data
    box = data_set.box

    print("Settings for calibration:")
    print("    sigma_x: ", sigma_x)
    print("    sigma_t: ", sigma_t)
    print("    delta_x: ", sobel_delta_x)
    print("    delta_t: ", sobel_delta_t)

    if config.taper and isinstance(data, np.ma.core.MaskedArray):
        print("    tapering on")
        taper_masked_area(data, [0, 5, 5], 50)

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
def generate_signal_plot(
        config, calibration, box, sobel_data, title, filename):
    lower, upper = get_thresholds(config, calibration)
    fig = plot_signal_histogram(box, 1 / sobel_data[3], lower, upper)
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


def maximum_suppression(sobel_data):
    mask = cp_edge_thinning(sobel_data.transpose([3, 2, 1, 0]).copy())
    return mask.transpose([2, 1, 0])


def get_thresholds(config, calibration):
    gamma = calibration['gamma'][3]
    mag_quartiles = np.sqrt(
        (calibration['distance'] * gamma)**2 + calibration['time']**2)

    values = {
        'pi-control-3': mag_quartiles[3],
        'pi-control-max': mag_quartiles[4],
        'pi-control-max*3/4': mag_quartiles[4] * 3/4,
        'pi-control-max*1/2': mag_quartiles[4] * 1/2
    }

    return values[config.lower_threshold], \
        values[config.upper_threshold]


def hysteresis_thresholding(config, sobel_data, mask, calibration):
    lower, upper = get_thresholds(config, calibration)
    print('    thresholds:', lower, upper)
    new_mask = cp_double_threshold(
        sobel_data.transpose([3, 2, 1, 0]).copy(),
        mask.transpose([2, 1, 0]),
        1. / upper,
        1. / lower)
    return new_mask.transpose([2, 1, 0])


@noodles.schedule
def apply_mask_to_edges(edges, mask, time_margin):
    edges[:time_margin] = 0
    edges[-time_margin:] = 0
    return edges * ~mask


@noodles.schedule
def transfer_magnitudes(x, y):
    x[3] = y[3]
    return x


@noodles.schedule(store=True, call_by_ref=['data_set'])
def compute_canny_edges(config, data_set, calibration):
    print("computing canny edges")
    data = data_set.data
    box = data_set.box

    sigma_t, sigma_x = get_sigmas(config)
    weights = get_sobel_weights(config, calibration)
    print("    calibrated weights:",
          ['{:~P}'.format(w) for w in weights])

    if config.taper and isinstance(data, np.ma.core.MaskedArray):
        print("    tapering")
        taper_masked_area(data, [0, 5, 5], 50)

    smooth_data = noodles.schedule(gaussian_filter)(
        box, data, [sigma_t, sigma_x, sigma_x])
    sobel_data = noodles.schedule(sobel_filter)(
        box, smooth_data, weight=weights)
    pixel_sobel = noodles.schedule(sobel_filter)(
        box, smooth_data, physical=False)
    pixel_sobel = transfer_magnitudes(pixel_sobel, sobel_data)
    sobel_maxima = noodles.schedule(maximum_suppression)(pixel_sobel)

    if isinstance(data, np.ma.core.MaskedArray):
        sobel_maxima = apply_mask_to_edges(sobel_maxima, data.mask, 10)

    edges = noodles.schedule(hysteresis_thresholding)(
        config, sobel_data, sobel_maxima, calibration)

    return noodles.gather_dict(
        sobel=sobel_data,
        edges=edges)


@noodles.schedule
def label_regions(mask, min_size=50):
    labels, n_features = ndimage.label(
        mask, ndimage.generate_binary_structure(3, 3))
    big_enough = [x for x in range(1, n_features+1)
                  if (labels == x).sum() > min_size]
    return noodles.gather_dict(
        n_features=n_features,
        regions=np.where(np.isin(labels, big_enough), labels, 0),
        labels=big_enough)


@noodles.schedule(store=True)
def generate_region_plot(box, mask, title, filename, min_size=50):
    labels, n_features = ndimage.label(
        mask, ndimage.generate_binary_structure(3, 3))
    print('    n_features:', n_features)
    big_enough = [x for x in range(1, n_features+1)
                  if (labels == x).sum() > min_size]
    regions = np.where(np.isin(labels, big_enough), labels, 0)
    fig = plot_plate_carree(box, regions.max(axis=0))
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule(store=True)
def generate_year_plot(box, mask, title, filename):
    years = np.array([d.year for d in box.dates])
    data = (years[:, None, None] * mask).max(axis=0)
    fig = plot_plate_carree(
        box, data, cmap='YlGnBu', vmin=years[0], vmax=years[-1])
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule(store=True)
def generate_event_count_plot(box, mask, title, filename):
    fig = plt.figure()
    ax = fig.add_subplot(111)
    ax.plot(box.dates, mask.sum(axis=1).sum(axis=1))
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


def generate_report(config):
    output_path = Path(config.output_folder)
    output_path.mkdir(parents=True, exist_ok=True)

    control_set = open_pi_control(config)
    calibration = compute_calibration(config, control_set)

    data_set = open_data_files(config)
    canny_edges = compute_canny_edges(config, data_set, calibration)

    signal_plot = generate_signal_plot(
        config, calibration, data_set.box, canny_edges['sobel'], "signal",
        output_path / "signal.png")
    region_plot = generate_region_plot(
        data_set.box, canny_edges['edges'], "regions",
        output_path / "regions.png")
    year_plot = generate_year_plot(
        data_set.box, canny_edges['edges'], "years",
        output_path / "years.png")
    event_count_plot = generate_event_count_plot(
        data_set.box, canny_edges['edges'], "event count",
        output_path / "event_count.png")

    return noodles.lift({
        'calibration': calibration,
        'signal_plot': signal_plot,
        'region_plot': region_plot,
        'year_plot': year_plot,
        'event_count_plot': event_count_plot
    })
