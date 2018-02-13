import warnings
import sys
from pathlib import Path

warnings.simplefilter(action='ignore', category=FutureWarning)


def weave_report(config):
    path = Path(__file__).parent / 'templates' / 'report.mdw'
    template = path.open().read()
    text = template.format(**vars(config))
    print(text)


def print_nlesc_logo():
    print("\n     \033[47;30m Netherlands\033[48;2;0;174;239;37m▌"
          "\033[38;2;255;255;255me\u20d2Science\u20d2\033[37m▐"
          "\033[47;30mcenter \033[m"
          "          ╒═══════════════════════════╕\n"
          "                  and               "
          "        │ HyperCanny Climate module │\n"
          " \033[47;30m \033[38;2;42;128;41;4m⊓ \033[24m"
          "\033[38;2;0;74;109m Wageningen"
          "\033[38;2;42;128;41m University & Research \033[m  "
          "    ╰───────────────────────────╯\n", file=sys.stderr)


if __name__ == "__main__":
    import argparse
    import logging

    # disable interactive plotting
    import matplotlib
    matplotlib.use('SVG')

    from noodles.run.threading.sqlite3 import run_parallel as run

    from .workflow import generate_report
    from .units import MONTHS
    from .serialisers import registry

    import multiprocessing
    N_CORES = multiprocessing.cpu_count()

    print_nlesc_logo()
    logging.getLogger('root').setLevel(logging.WARNING)
    logging.getLogger('noodles').setLevel(logging.WARNING)
    logging.info("This message should show.")

    parser = argparse.ArgumentParser(
        prog='hypercc',
        description="Detect edges in climate data")
    parser.add_argument(
        "--data-folder", help="path to search for NetCDF files "
        "(default: %(default)s)",
        default='.', dest='data_folder')
    subparser = parser.add_subparsers(
        help="command to run", dest='command')

    report_parser = subparser.add_parser(
        "report", help="generate complete report")
    report_parser.set_defaults(func=generate_report)

    report_parser.add_argument(
        "--model", help="model name in CMIP5 naming scheme",
        required=True, dest='model')
    report_parser.add_argument(
        "--scenario", help="scenario name in CMIP5 naming scheme",
        required=True, dest='scenario')
    report_parser.add_argument(
        "--variable", help="variable name in CMIP5 naming scheme",
        required=True, dest='variable')
    report_parser.add_argument(
        "--realization", help="realization name in CMIP5 naming scheme "
        "(default: %(default)s)",
        default='r1i1p1', dest='realization')
    report_parser.add_argument(
        "--extension", help="extension to data files (default: %(default)s)",
        default='nc', dest='extension')
    report_parser.add_argument(
        "--month", help="which month to study, give abbreviated month name "
        "as by your locale.",
        default=MONTHS[0], choices=MONTHS)
    report_parser.add_argument(
        "--sigma-x", help="spacial smoothing scale, quantity with unit "
        "(default: 200 km)",
        nargs=2, default=['200', 'km'], dest='sigma_x')
    report_parser.add_argument(
        "--sigma-t", help="temporal smoothing scale, quantity with unit"
        "(default: 10 year)",
        nargs=2, default=['10', 'year'], dest='sigma_t')
    report_parser.add_argument(
        "--upper-threshold", help="method for estimating upper threshold "
        "(default: %(default)s)", choices=['pi-control-max'],
        default='pi-control-max', dest='upper_threshold')
    report_parser.add_argument(
        "--lower-threshold", help="method for estimating lower threshold "
        "(default: %(default)s)", choices=['pi-control-3'],
        default='pi-control-3', dest='lower_threshold')
    report_parser.add_argument(
        "--sobel-scale", help="scaling of time/space in magnitude of Sobel"
        " operator, should have dimensionality of velocity. (default: "
        "10 km/year)", nargs=2, default=['10', 'km/year'], dest='sobel_scale')
    report_parser.add_argument(
        "--no-taper", help="taper data to handle land/sea mask.",
        dest='taper', action='store_false')

    args = parser.parse_args()
    if args.command == 'report':
        workflow = args.func(args)
        result = run(workflow, n_threads=N_CORES, registry=registry,
                     db_file='hypercc-cache.db', always_cache=False,
                     echo_log=False)
        print(result['calibration'])
