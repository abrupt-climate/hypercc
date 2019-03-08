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


def run_single(workflow, db_file='hypercc-cache.db'):
    from noodles.run.single.sqlite3 import run_single
    from .serialisers import registry
    return run_single(
        workflow, registry=registry,
        db_file=db_file, always_cache=False)


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


@noodles.schedule(call_by_ref=['data_set'])
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
    #print("Calibration gamma[{}] = {}"
    #      .format(config.calibration_quartile, gamma))
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
    fig.suptitle(title, fontsize=20)
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
    lower, upper = get_thresholds(config, calibration)
    print("maximum signal in control:", upper)
    print("maximum signal in data:", max_signal_value)
    if max_signal_value < upper:
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
    maxTgrad[np.isnan(maxTgrad)]=0                    # can be nan when var is constant
    indices_mask=np.where(maxTgrad>np.max(maxTgrad))  # set missing values to 0
    maxTgrad[indices_mask]=0                          # otherwise they show on map
    return maxTgrad


@noodles.schedule(call_by_ref=['mask'])
@noodles.maybe
def compute_measure15(mask, years, data, cutoff_length, chunk_max_length, chunk_min_length):
    from scipy import stats

    idx = np.where(mask)
    indices=np.asarray(idx)
    measure15_3d=mask*0.0

    shapeidx=np.shape(idx)
    nofresults=shapeidx[1]

    for result in range(nofresults):
        [dim0,dim1,dim2]=indices[:,result]

        if mask[dim0, dim1, dim2] == 1:
            index=dim0
            chunk1_data=data[0:index-cutoff_length+2,dim1,dim2]
            chunk2_data=data[index+cutoff_length:,dim1,dim2]
            chunk1_years=years[0:index-cutoff_length+2]
            chunk2_years=years[index+cutoff_length:]

            if np.size(chunk1_data) > chunk_max_length-1:
                chunk1_start=-chunk_max_length-1
            else:
                chunk1_start=-np.size(chunk1_data)-1
            if np.size(chunk2_data) > chunk_max_length-1:
                chunk2_end=chunk_max_length
            else:
                chunk2_end=np.size(chunk2_data)

            chunk1_data_short=chunk1_data[chunk1_start:-1]
            chunk2_data_short=chunk2_data[0:chunk2_end]
            N1=np.size(chunk1_data_short)
            N2=np.size(chunk2_data_short)

            if not ((N1 < chunk_min_length) or (N2 < chunk_min_length)):
                chunk1_years_short=chunk1_years[chunk1_start:-1]-years[dim0]
                chunk2_years_short=chunk2_years[0:chunk2_end]-years[dim0]

                slope_chunk1, intercept_chunk1, r_value, p_value, std_err = stats.linregress(chunk1_years_short, chunk1_data_short)
                chunk1_regline=intercept_chunk1 + slope_chunk1*chunk1_years_short

                slope_chunk2, intercept_chunk2, r_value, p_value, std_err = stats.linregress(chunk2_years_short, chunk2_data_short)
                chunk2_regline=intercept_chunk2 + slope_chunk2*chunk2_years_short

                chunk1_residuals=chunk1_data_short - (intercept_chunk1 + slope_chunk1*chunk1_years_short)
                chunk2_residuals=chunk2_data_short - (intercept_chunk2 + slope_chunk2*chunk2_years_short)

                mean_std=(np.nanstd(chunk1_residuals)+np.nanstd(chunk2_residuals))/2
                measure15_3d[dim0,dim1,dim2]=abs(intercept_chunk1-intercept_chunk2)/mean_std
    measure15=np.max(measure15_3d,axis=0)
    measure15[np.isnan(measure15)]=0
    indices_mask=np.where(measure15>np.max(measure15))  # set missing values to 0
    measure15[indices_mask]=0                           # otherwise they show on map
    return {
	'measure15_3d': measure15_3d,
	'measure15':    measure15
    }


@noodles.schedule
@noodles.maybe
def write_map(field, filename):
   file = open(str(filename),'w')
   np.savetxt(file, field, delimiter=" ")
   file.close()


@noodles.schedule
@noodles.maybe
def generate_standard_map_plot(box, abruptness, title, filename):
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    if np.max(abs(abruptness)) > 0:
        fig = plot_plate_carree(box, abruptness, cmap=my_cmap, vmin=1e-30)
    else:
        fig = plot_plate_carree(box, abruptness, cmap=my_cmap, vmin=-1e-30, vmax=1e-30)
    fig.suptitle(title, fontsize=20)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)



@noodles.schedule
@noodles.maybe
def generate_timeseries_plot(config, box, data, field1, title, filename):
    import matplotlib
    sigma_t, sigma_x = get_sigmas(config)
    if np.max(abs(field1)) > 0:
        lonind=np.nanargmax(np.nanmax(field1, axis=0))
        latind=np.nanargmax(np.nanmax(field1, axis=1))
        ts1=data[:,latind,lonind]
        fig = plt.figure()
        ax=plt.subplot(111)
        ax.plot(box.dates, ts1, 'k')
        fig.suptitle(title, fontsize=20)
        ax.set_xlabel('year', fontsize=20)
        ax.set_ylabel('data', fontsize=20)
        fig.savefig(str(filename), bbox_inches='tight')
        return Path(filename)


@noodles.schedule(call_by_ref=['mask'])
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


@noodles.schedule(call_by_ref=['mask'])
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



@noodles.schedule(store=False,call_by_ref=['mask'])
@noodles.maybe
def generate_scatter_plot(mask,sb,colourdata,sizedata,colourbarlabel,gamma,lower_threshold,upper_threshold,title,filename):

    ### obtain location of edges in space and time, the magnitude of the gradients and their abruptness
    ## arrays with data from the points with edges (mask==1)
    idx    = np.where(mask)
    sizdata  = sizedata[idx[0], idx[1], idx[2]]
    coldata  = colourdata[idx[0], idx[1], idx[2]]
    sobel  = sb[:, idx[0], idx[1], idx[2]]
    sgrad = np.sqrt(sobel[1]**2 + sobel[2]**2) / gamma
    sgrad = sgrad/sobel[3]*1000    # scale to 1000 km
    tgrad = sobel[0]/sobel[3]*10      # scale to 10 years

    #### sort the input in order to show most abrupt ones on top of the others in scatter plot
    inds = np.argsort(coldata)

    ######## plot
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    fig = plt.figure()
    ax=plt.subplot(111)
    matplotlib.rc('xtick', labelsize=16)
    matplotlib.rc('ytick', labelsize=16)
    
    #### ellipses showing the threshold values of hysteresis thresholding
    dp = np.linspace(-np.pi/2, np.pi/2, 100)
    dt = upper_threshold * np.sin(dp) * 10
    dx = upper_threshold * np.cos(dp) * 10 / gamma*1000

    # ellipse showing the aspect ratio. for scaling_factor=1 would be a circle
    # the radius of that circle is the upper threshold
    plt.plot(dx, dt, c='k')

    ## ellipse based on the lower threshold:
    dt = lower_threshold * np.sin(dp) * 10
    dx = lower_threshold * np.cos(dp) * 10 / gamma*1000
    plt.plot(dx, dt, c='k')

    #data
    plt.scatter(sgrad[inds], tgrad[inds],s=sizdata[inds]**2,c=coldata[inds], marker = 'o', cmap =my_cmap );
    cbar=plt.colorbar()
    cbar.set_label(colourbarlabel)
    matplotlib.rcParams.update({'font.size': 16})
    ax.set_xlabel('spatial gradient in units / 1000 km')
    ax.set_ylabel('temporal gradient in units / decade')


    #### set axis ranges
    border=0.05
    Smin=np.min(sgrad)-(np.max(sgrad)-np.min(sgrad))*border
    Smax=np.max(sgrad)+(np.max(sgrad)-np.min(sgrad))*border
    Tmin=np.min(tgrad)-(np.max(tgrad)-np.min(tgrad))*border
    Tmax=np.max(tgrad)+(np.max(tgrad)-np.min(tgrad))*border
    ax.set_xlim(Smin, Smax)
    ax.set_ylim(Tmin, Tmax)

    #fig.suptitle(title)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule(call_by_ref=['mask','abruptness_3d','abruptness'])
@noodles.maybe
def compute_years_maxabrupt(box, mask, abruptness_3d, abruptness):
    idx=np.where(mask)
    indices=np.asarray(idx)
    mask_max=mask*0
    shapeidx=np.shape(idx)
    nofresults=shapeidx[1]
    for result in range(nofresults):
        [dim0,dim1,dim2]=indices[:,result]
        if (abruptness_3d[dim0, dim1, dim2] == abruptness[dim1,dim2]) and abruptness[dim1,dim2] > 0:
            mask_max[dim0, dim1, dim2] = 1
    years = np.array([dd.year for dd in box.dates])
    years_maxabrupt=(years[:,None,None]*mask_max).sum(axis=0)
    return years_maxabrupt

    
@noodles.schedule(call_by_ref=['years_maxabrupt'])
@noodles.maybe
def generate_year_plot(box, years_maxabrupt, title, filename):
    import matplotlib
    my_cmap = matplotlib.cm.get_cmap('rainbow')
    my_cmap.set_under('w')
    maxval = np.max(years_maxabrupt)
    minval = np.min(years_maxabrupt[np.nonzero(years_maxabrupt)])
    fig = plot_plate_carree(
        box, years_maxabrupt, cmap=my_cmap, vmin=minval, vmax=maxval)
    fig.suptitle(title, fontsize=20)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)


@noodles.schedule(call_by_ref=['mask'])
@noodles.maybe
def generate_event_count_timeseries_plot(box, mask, title, filename):
    fig = plt.figure()
    ax=plt.subplot(111)
    ax.plot(box.dates, mask.sum(axis=1).sum(axis=1))
    ax.set_title(title, fontsize=20)
    ax.set_xlabel('year', fontsize=20)
    ax.set_ylabel('events', fontsize=20)
    fig.savefig(str(filename), bbox_inches='tight')
    return Path(filename)

#
#@noodles.schedule(call_by_ref=['mask'])
#@noodles.maybe
#def generate_event_count_plot(box, mask, title, filename):
#    import matplotlib
#    my_cmap = matplotlib.cm.get_cmap('rainbow')
#    my_cmap.set_under('w')
#    if np.max(mask) > 0:
#        fig = plot_plate_carree(box, abruptness, cmap=my_cmap, vmin=1e-30)
#    else:
#        fig = plot_plate_carree(box, abruptness, cmap=my_cmap, vmin=-1e-30, vmax=1e-30)
#    fig.suptitle(title, fontsize=20)
#    fig.savefig(str(filename), bbox_inches='tight')
#
#    
#    return Path(filename)



@noodles.schedule(call_by_ref=['data_set', 'canny_edges'])
@noodles.maybe
def make_report(config, data_set, calibration, canny_edges):
    gamma = get_calibration_factor(config, calibration)
    years = np.array([dd.year for dd in data_set.box.dates])
    mask=canny_edges['edges']
    event_count=mask.sum(axis=0)
    
    lower_threshold, upper_threshold = get_thresholds(config, calibration)
    years3d=years[:,None,None]*mask
    lats=data_set.box.lat
    lats3d=lats[None,:,None]*mask
    lons=data_set.box.lon
    lons3d=lons[None,None,:]*mask
    
    maxTgrad      = compute_maxTgrad(canny_edges)
    
    ## abruptness
    measures      = compute_measure15(mask, years, data_set.data, 2, 30, 15)
    abruptness_3d = measures['measure15_3d']
    abruptness    = measures['measure15']

    years_maxabrupt = compute_years_maxabrupt(data_set.box, mask, abruptness_3d, abruptness)
    
    output_path  = Path(config.output_folder)
    signal_plot  = generate_signal_plot(
        config, calibration, data_set.box, canny_edges['sobel'], "signal",
        output_path / "signal.png")
    region_plot  = generate_region_plot(
        data_set.box, canny_edges['edges'], "regions",
        output_path / "regions.png")
    year_plot    = generate_year_plot(
        data_set.box, years_maxabrupt, "year of largest abruptness",
        output_path / "years_maxabrupt.png")
    event_count_timeseries_plot = generate_event_count_timeseries_plot(
        data_set.box, canny_edges['edges'], "event count",
        output_path / "event_count_timeseries.png")
    event_count_plot = generate_standard_map_plot(
        data_set.box, event_count, "event count",
        output_path / "event_count.png")
    abruptness_plot  = generate_standard_map_plot(
        data_set.box, abruptness,
        "abruptness", output_path / "abruptness.png")
    maxTgrad_plot    = generate_standard_map_plot(
        data_set.box, maxTgrad,
        "max. time gradient", output_path / "maxTgrad.png")
    timeseries_plot = generate_timeseries_plot(
        config, data_set.box, data_set.data, abruptness, "data at grid cell with largest abruptness",
        output_path / "timeseries.png")
    scatter_plot_abrupt=generate_scatter_plot(
        mask,canny_edges['sobel'],abruptness_3d,abruptness_3d,"abruptness",gamma,lower_threshold,
        upper_threshold,"space versus time gradients", output_path / "scatter_abruptness.png")
    scatter_plot_years=generate_scatter_plot(
        mask,canny_edges['sobel'],years3d,abruptness_3d,"year",gamma,lower_threshold,
        upper_threshold,"space versus time gradients",output_path / "scatter_year.png")
    scatter_plot_lats=generate_scatter_plot(
        mask,canny_edges['sobel'],lats3d,abruptness_3d,"latitude",gamma,lower_threshold,
        upper_threshold,"space versus time gradients",output_path / "scatter_latitude.png")
    scatter_plot_lons=generate_scatter_plot(
        mask,canny_edges['sobel'],lons3d,abruptness_3d,"longitude",gamma,lower_threshold,
        upper_threshold,"space versus time gradients",output_path / "scatter_longitude.png")
    maxTgrad_out        = write_map(maxTgrad, output_path / "maxTgrad.txt")
    abruptness_out      = write_map(abruptness, output_path / "abruptness.txt")
    years_maxabrupt_out = write_map(years_maxabrupt, output_path / "years_maxabrupt.txt")
    event_count_out     = write_map(event_count, output_path / "event_count.txt")
    
    return noodles.lift({
        'calibration': calibration,
        'statistics': {
            'max_maxTgrad': maxTgrad.max(),
            'max_abruptness': abruptness.max()
        },
        'signal_plot': signal_plot,
        'region_plot': region_plot,
        'year_plot': year_plot,
        'event_count_plot': event_count_plot,
        'event_count_timeseries_plot': event_count_timeseries_plot,
        'maxTgrad_plot': maxTgrad_plot,
        'abruptness_plot': abruptness_plot,
        'timeseries_plot': timeseries_plot,
        'scatter_plot_abrupt': scatter_plot_abrupt,
        'scatter_plot_years': scatter_plot_years,
        'scatter_plot_lats': scatter_plot_lats,
        'scatter_plot_lons': scatter_plot_lons,
        'maxTgrad_out': maxTgrad_out,
        'abruptness_out': abruptness_out,
        'years_maxabrupt_out': years_maxabrupt_out,
        'event_count_out': event_count_out
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
