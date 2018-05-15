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


def run(workflow, db_file='hypercc-cache.db'):
    from noodles.run.threading.sqlite3 import run_parallel
    from .serialisers import registry
    import multiprocessing

    N_CORES = multiprocessing.cpu_count()

    return run_parallel(
        workflow, n_threads=N_CORES, registry=registry,
        db_file=db_file, always_cache=False,
        echo_log=False)


def open_data_files(config):
    """Open data files from the settings given in `config`.

    :param config: namespace object (as returned by argparser)
    :return: DataSet
    """
    data_set = DataSet.cmip5(
        path=config.data_folder,
        model=config.model,
        variable=config.variable,
        scenario=config.scenario,
        realization=config.realization,
        extension=config.extension
    )

    return data_set


def open_pi_control(config):
    if config.pi_control_folder:
        pi_control_folder = config.pi_control_folder
    else:
        pi_control_folder = config.data_folder

    control_set = DataSet.cmip5(
        path=pi_control_folder,
        model=config.model,
        variable=config.variable,
        scenario='piControl',
        extension=config.extension,
        realization=config.realization)

    return control_set


@noodles.schedule(call_by_ref=['data_set'])
@noodles.maybe
def select_month(config, data_set):
    month = month_index(config.month)
    return data_set[month::12]


@noodles.schedule(call_by_ref=['data_set'])
@noodles.maybe
def annual_mean(data_set):
    print("Computing annual mean.")
    return data_set.annual_mean()


@noodles.schedule(store=True, call_by_ref=['data_set'])
def compute_calibration(config, data_set):
    quartile = ['min', '1st', 'median', '3rd', 'max'] \
        .index(config.calibration_quartile)

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

    smooth_data = noodles.schedule(gaussian_filter, call_by_ref=['data'])(
        box, data, [sigma_t, sigma_x, sigma_x])
    calibration = noodles.schedule(calibrate_sobel, call_by_ref=['data'])(
        quartile, box, smooth_data, sobel_delta_t, sobel_delta_x)

    return calibration


def get_calibration_factor(config, calibration):
    quartile = ['min', '1st', 'median', '3rd', 'max'] \
        .index(config.calibration_quartile)
    gamma = calibration['gamma'][quartile]
    print("Calibration gamma[{}] = {}"
          .format(config.calibration_quartile, gamma))
    return gamma


def get_sigmas(config):
    sigma_t = float(config.sigma_t[0]) * unit(config.sigma_t[1])
    sigma_x = float(config.sigma_x[0]) * unit(config.sigma_x[1])
    return sigma_t, sigma_x


def get_sobel_weights(config, calibration):
    sobel_scale = float(config.sobel_scale[0]) * unit(config.sobel_scale[1])
    gamma = get_calibration_factor(config, calibration)
    sobel_delta_t = 1.0 * unit.year
    sobel_delta_x = sobel_delta_t * sobel_scale * gamma
    return [sobel_delta_t, sobel_delta_x, sobel_delta_x]


@noodles.schedule
@noodles.maybe
def generate_signal_plot(
        config, calibration, box, sobel_data, title, filename):
    lower, upper = get_thresholds(config, calibration)
    fig = plot_signal_histogram(box, 1 / sobel_data[3], lower, upper)
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule(call_by_ref=['sobel_data'])
@noodles.maybe
def maximum_suppression(sobel_data):
    print("transposing data")
    trdata = sobel_data.transpose([3, 2, 1, 0]).copy()
    print("applying thinning")
    mask = cp_edge_thinning(trdata)
    return mask.transpose([2, 1, 0])


def get_thresholds(config, calibration):
    gamma = get_calibration_factor(config, calibration)
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


@noodles.schedule(call_by_ref=['sobel_data', 'mask'])
@noodles.maybe
def hysteresis_thresholding(config, sobel_data, mask, calibration):
    lower, upper = get_thresholds(config, calibration)
    print('    thresholds:', lower, upper)
    new_mask = cp_double_threshold(
        sobel_data.transpose([3, 2, 1, 0]).copy(),
        mask.transpose([2, 1, 0]),
        1. / upper,
        1. / lower)
    return new_mask.transpose([2, 1, 0])


@noodles.schedule(call_by_ref=['edges', 'mask'])
@noodles.maybe
def apply_mask_to_edges(edges, mask, time_margin):
    edges[:time_margin] = 0
    edges[-time_margin:] = 0
    return edges * ~mask


@noodles.schedule(call_by_ref=['x', 'y'])
def transfer_magnitudes(x, y):
    x[3] = y[3]
    return x


@noodles.schedule(call_by_ref=['sobel_data'])
def max_signal(sobel_data):
    """Compute the maximum signal."""
    return 1. / sobel_data[-1].min()


@noodles.schedule(call_by_ref=['data_set'])
@noodles.maybe
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

    smooth_data = gaussian_filter(box, data, [sigma_t, sigma_x, sigma_x])
    sobel_data = sobel_filter(box, smooth_data, weight=weights)

    max_signal_value = 1 / sobel_data[-1].min()
    max_cal = calibration['magnitude'][4]
    print("maximum signal in control:", max_cal)
    print("maximum signla in data:", max_signal_value)
    if max_signal_value < max_cal:
        raise ValueError("Maximum signal below calibration limit, no need to continue.");

    pixel_sobel = sobel_filter(box, smooth_data, physical=False)
    pixel_sobel = transfer_magnitudes(pixel_sobel, sobel_data)
    sobel_maxima = maximum_suppression(pixel_sobel)

    if isinstance(data, np.ma.core.MaskedArray):
        sobel_maxima = apply_mask_to_edges(sobel_maxima, data.mask, 10)

    edges = hysteresis_thresholding(config, sobel_data, sobel_maxima, calibration)

    return noodles.gather_dict(
        sobel=sobel_data,
        edges=edges)


@noodles.schedule
@noodles.maybe
def compute_maxTgrad(canny):
    tgrad = canny['sobel'][0]/canny['sobel'][3]       # unit('1/year');
    tgrad_residual = tgrad - np.mean(tgrad, axis=0)   # remove time mean
    maxm = canny['edges'].max(axis=0)		      # mask
    maxTgrad = np.max(abs(tgrad_residual), axis=0)    # maximum of time gradient
    maxTgrad = maxTgrad * maxm
    indices_mask=np.where(maxTgrad>np.max(maxTgrad))  # set missing values to 0
    maxTgrad[indices_mask]=0                           # otherwise they show on map
    return maxTgrad


@noodles.schedule
@noodles.maybe
def compute_peakiness(canny):
    tgrad = canny['sobel'][0]/canny['sobel'][3]      # unit('1/year');
    tgrad_residual = tgrad - np.mean(tgrad, axis=0)  # remove time mean
    maxTgrad = np.max(abs(tgrad_residual), axis=0)   # maximum of time gradient
    stdevdist = np.std(tgrad_residual, axis=0)       # stdev
    maxm = canny['edges'].max(axis=0)		     # mask
    peakiness = maxTgrad / stdevdist                 # peakines = maxdist/stdev
    peakiness = peakiness * maxm                     # 0 where no event
    indices_mask=np.where(peakiness>np.max(peakiness))  # set missing values to 0
    peakiness[indices_mask]=0                           # otherwise they show on map
    return peakiness


@noodles.schedule
@noodles.maybe
def generate_peakiness_plot(box, peakiness, title, filename):
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    fig = plot_plate_carree(box, peakiness, cmap=my_cmap, vmin=1e-30)
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule
@noodles.maybe
def generate_maxTgrad_plot(box, maxTgrad, title, filename):
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    fig = plot_plate_carree(box, maxTgrad, cmap=my_cmap, vmin=1e-30)
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule
@noodles.maybe
def generate_timeseries_plot(box, data, maxTgrad, peakiness, title, filename):
    import matplotlib
    lonind=np.argmax(np.max(peakiness, axis=0))
    latind=np.argmax(np.max(peakiness, axis=1))
    tspeak=data[:,latind,lonind]
    lonind=np.argmax(np.max(maxTgrad, axis=0))
    latind=np.argmax(np.max(maxTgrad, axis=1))
    tsgrad=data[:,latind,lonind]
    fig = plt.figure()
    ax = fig.add_subplot(111)
    ax.plot(box.dates, tspeak, 'k', box.dates, tsgrad, 'r')
    fig.suptitle(title)
    #fig.legend('ts with largest peakiness','ts with largest time gradient', 'Location','Best')
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule
@noodles.maybe
def label_regions(mask, min_size=0):
    labels, n_features = ndimage.label(
        mask, ndimage.generate_binary_structure(3, 3))
    big_enough = [x for x in range(1, n_features+1)
                  if (labels == x).sum() > min_size]
    return noodles.gather_dict(
        n_features=n_features,
        regions=np.where(np.isin(labels, big_enough), labels, 0),
        labels=big_enough)


@noodles.schedule
@noodles.maybe
def generate_region_plot(box, mask, title, filename, min_size=0):
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    labels, n_features = ndimage.label(
        mask, ndimage.generate_binary_structure(3, 3))
    print('    n_features:', n_features)
    if n_features > 0:
    	big_enough = [x for x in range(1, n_features+1)
        	          if (labels == x).sum() > min_size]
    	regions = np.where(np.isin(labels, big_enough), labels, 0)
    	regions_show=regions.max(axis=0)
    	fig = plot_plate_carree(box, regions_show, cmap=my_cmap, vmin=1)
    	fig.suptitle(title)
    	fig.savefig(str(filename), bbox_inches='tight')
    	return Path(filename)


@noodles.schedule
@noodles.maybe
def generate_year_plot(box, mask, title, filename):
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    years = np.array([d.year for d in box.dates])
    data = (years[:, None, None] * mask).max(axis=0)
    fig = plot_plate_carree(
        box, data, cmap=my_cmap, vmin=years[0], vmax=years[-1])
#    fig = plot_plate_carree(
       # box, data, cmap='YlGnBu', vmin=years[0], vmax=years[-1])
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule
@noodles.maybe
def generate_event_count_plot(box, mask, title, filename):
    fig = plt.figure()
    ax = fig.add_subplot(111)
    ax.plot(box.dates, mask.sum(axis=1).sum(axis=1))
    fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule(call_by_ref=['data_set', 'canny_edges'])
@noodles.maybe
def make_report(config, data_set, calibration, canny_edges):
    maxTgrad = compute_maxTgrad(canny_edges)
    peakiness = compute_peakiness(canny_edges)
    output_path = Path(config.output_folder)

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
    peakiness_plot = generate_peakiness_plot(
        data_set.box, peakiness,
        "peakiness", output_path / "peakiness.png")
    maxTgrad_plot = generate_maxTgrad_plot(
        data_set.box, maxTgrad,
        "max. time gradient", output_path / "maxTgrad.png")
    timeseries_plot = generate_timeseries_plot(
        data_set.box, data_set.data, maxTgrad, peakiness, "timeseries",
        output_path / "timeseries.png")

    return noodles.lift({
        'calibration': calibration,
        'statistics': {
            'max_peakiness': peakiness.max(),
            'max_maxTgrad': maxTgrad.max()
        },
        'signal_plot': signal_plot,
        'region_plot': region_plot,
        'year_plot': year_plot,
        'event_count_plot': event_count_plot,
        'peakiness_plot': peakiness_plot,
        'maxTgrad_plot': maxTgrad_plot,
        'timeseries_plot': timeseries_plot
    })


def generate_report(config):
    output_path = Path(config.output_folder)
    output_path.mkdir(parents=True, exist_ok=True)

    data_set = open_data_files(config)
    control_set = open_pi_control(config)

    if config.annual:
        data_set = annual_mean(data_set)
        control_set = annual_mean(control_set)
    else:
        data_set = select_month(config, data_set)
        control_set = select_month(config, control_set)

    calibration = compute_calibration(config, control_set)
    canny_edges = compute_canny_edges(config, data_set, calibration)
    return make_report(config, data_set, calibration, canny_edges)
