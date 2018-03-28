"""
Handles a series of NetCDF files.
"""

from pathlib import Path
from copy import copy

import numpy as np

from .file import File
from .box import Box


def overlap_idx(t1, t2):
    """Takes two sorted sequences `t1` and `t2`. Where `t1` becomes larger
    than `t2[0]`, we'd like to cut off `t1`.

    Returns: a slice for selecting `t1` upto the point where it gets larger
    than `t2[0]`."""
    idx = np.where(t1 >= t2[0])[0]
    if len(idx) == 0:
        return slice(None)
    else:
        return slice(0, idx[0])


class DataSet(object):
    def __init__(self, paths, variable, selection=slice(None)):
        self.files = None
        self.paths = paths
        self.variable = variable
        self.selection = selection
        self._box = None

        self.check_and_load()

    @staticmethod
    def cmip5(path, model: str, variable: str, scenario: str,
              realization: str, extension="nc", selection=slice(None)):
        pattern = f"{variable}_*mon_{model}_{scenario}" \
                  f"_{realization}_??????-??????.{extension}".format(variable=variable, model=model, scenario=scenario, realization=realization, extension=extension)
        paths = list(Path(path).glob(pattern))
        return DataSet(paths=paths, variable=variable, selection=selection)

    def __serialize__(self, pack):
        return pack({
            'paths': self.paths,
            'variable': self.variable,
            'selection': self.selection
        })

    @classmethod
    def __construct__(cls, data):
        return DataSet(**data)

    def load(self):
        """Open files, find overlaps."""
        self.files = sorted(
            list(map(File, self.paths)),
            key=lambda f: f.time[0])

        bounds = [overlap_idx(self.files[i].time, self.files[i+1].time)
                  for i in range(len(self.files) - 1)] + [slice(None)]

        for f, b in zip(self.files, bounds):
            f.bounds = b

    def check_and_load(self):
        """Checks if files exist that match the given pattern. Then loads them
        and checks if the coordinates are rectangular.

        Raises:
        *   FileNotFoundError if files were not found.
        *   ValueError if the grid is not rectangular.
        """
        for p in self.paths:
            if not p.exists():
                raise FileNotFoundError(p)

        self.load()

        if not self.box.rectangular:
            raise ValueError("Rectangular grid needed.")

    def __getitem__(self, selection):
        result = copy(self)
        result.selection = selection
        return result

    @property
    def box(self):
        """Box from data sets."""
        if self._box is None:
            time = np.concatenate([f.time for f in self.files])
            lat = self.files[0].lat
            lon = self.files[0].lon

            try:
                lat_bnds = self.files[0].lat_bnds
                lon_bnds = self.files[0].lon_bnds

                # some files in CMIP5 are insane
                lon_bnds = np.where(
                    (abs(lon_bnds[:, 1] - lon_bnds[:, 0]) > 180)[:, None],
                    lon_bnds + [-180, 180], lon_bnds)

            except KeyError:
                lat_bnds = np.zeros(shape=(len(lat), 2), dtype='float32')
                if lat[0] > lat[-1]:
                    lat_bnds[0, 1] = 90.0
                    lat_bnds[1:, 1] = (lat[:-1] + lat[1:]) / 2
                    lat_bnds[:-1, 0] = (lat[:-1] + lat[1:]) / 2
                    lat_bnds[-1, 0] = -90.0
                else:
                    lat_bnds[0, 0] = -90.0
                    lat_bnds[1:, 0] = (lat[:-1] + lat[1:]) / 2
                    lat_bnds[:-1, 1] = (lat[:-1] + lat[1:]) / 2
                    lat_bnds[-1, 1] = 90.0

                lon_bnds = np.zeros(shape=(len(lon), 2), dtype='float32')
                lon_bnds[:, 0] = (np.roll(lon, 1) + lon) / 2
                lon_bnds[0, 0] -= 180
                lon_bnds[:, 1] = (np.roll(lon, -1) + lon) / 2
                lon_bnds[-1, 1] += 180

            dt, t0 = self.files[0].time_units
            self._box = Box(time, lat, lon, lat_bnds, lon_bnds, dt, t0)

        return self._box[self.selection]

    @property
    def data(self):
        """Concatenates data from entire dataset into single array."""
        return np.ma.concatenate(
            [f.get_masked(self.variable)
             for f in self.files])[self.selection]
