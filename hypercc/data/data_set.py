"""
Handles a series of NetCDF files.
"""

from pathlib import Path

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
    """Deals with sets of NetCDF files, combines data, and
    generates a valid :py:class:`Box` instance from these files.
    """
    pattern = "{variable}_*mon_{model}_{scenario}" \
              "_{realization}_??????-??????.{extension}"

    def __init__(self, *, path, model: str, variable: str, scenario: str,
                 realization: str, extension="nc"):
        self.path = Path(path)
        self.model = model
        self.variable = variable
        self.scenario = scenario
        self.realization = realization
        self.extension = extension

        self._box = None
        self.files = None

        self.check()

    def __serialize__(self, pack):
        return pack({
            'path': str(self.path),
            'model': self.model,
            'variable': self.variable,
            'scenario': self.scenario,
            'realization': self.realization,
            'extension': self.extension
        }, files=[str(f.path) for f in self.files])

    @classmethod
    def __construct__(cls, data):
        return DataSet(**data)

    def check(self):
        """Checks if files exist that match the given pattern. Then loads them
        and checks if the coordinates are rectangular.

        Raises:
        *   FileNotFoundError if files were not found.
        *   ValueError if the grid is not rectangular.
        """
        if not self.glob():
            raise FileNotFoundError(self.glob_pattern)

        self.load()

        if not self.box.rectangular:
            raise ValueError("Rectangular grid needed.")

    @property
    def glob_pattern(self):
        """Produce glob pattern."""
        return self.pattern.format(**self.__dict__)

    def glob(self):
        """Find files."""
        return list(self.path.glob(self.glob_pattern))

    def load(self):
        """Open files, find overlaps."""
        self.files = sorted(
            list(map(File, self.glob())),
            key=lambda f: f.time[0])

        bounds = [overlap_idx(self.files[i].time, self.files[i+1].time)
                  for i in range(len(self.files) - 1)] + [slice(None)]

        for f, b in zip(self.files, bounds):
            f.bounds = b

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

        return self._box

    @property
    def data(self):
        """Concatenates data from entire dataset into single array."""
        return np.ma.concatenate(
            [f.get_masked(self.variable) for f in self.files])
