"""
Box stores knowledge about
"""

from copy import copy
from datetime import timedelta, date

import numpy as np

from ..units import R_EARTH, DAY
from .file import parse_time_units


def is_linear(a, eps=1e-3):
    """Check if array of numbers is approximately linear."""
    x = np.diff(a[1:-1]).std() / np.diff(a[1:-1]).mean()
    return x < eps


class Box:
    """Stores properties of the coordinate system used."""
    def __init__(self, time, lat, lon,
                 lat_bnds=None, lon_bnds=None,
                 time_units='days',
                 time_start=date(1850, 1, 1)):
        self.time = time
        self.lat = lat
        self.lon = lon
        self.lat_bnds = lat_bnds
        self.lon_bnds = lon_bnds

        self.time_units = time_units
        self.time_start = time_start

    def __serialize__(self, pack):
        return pack({
            'time': self.time,
            'lat': self.lat,
            'lon': self.lon,
            'lat_bnds': self.lat_bnds,
            'lon_bnds': self.lon_bnds,
            'time_units': self.time_units,
            'time_start': self.time_start
        })

    @classmethod
    def __construct__(cls, data):
        return Box(**data)

    @staticmethod
    def from_netcdf(nc):
        """Obtain latitude, longitude and time axes from a given
        NetCDF object.

        :param nc: NetCDF dataset.
        """
        lat = nc.variables['lat'][:]
        lon = nc.variables['lon'][:]
        lat_bnds = nc.variables['lat_bnds'][:]
        lon_bnds = nc.variables['lon_bnds'][:]
        time = nc.variables['time'][:]
        dt, t0 = parse_time_units(nc.variables['time'].units)
        return Box(time, lat, lon, lat_bnds, lon_bnds, dt, t0)

    @staticmethod
    def generate(n_lon):
        """Generate a box without time axis, with the given number of pixels in
        the longitudinal direction. Latitudes are given half that size to
        create a 2:1 rectangular projection.

        :param n_lon: number of pixels in longitudinal direction.
        """
        n_lat = n_lon // 2
        lat = np.linspace(-90.0, 90, n_lat + 1)[1:-1]
        lon = np.linspace(0., 360., n_lon, endpoint=False)
        time = None
        return Box(time, lat, lon)

    def date(self, value):
        """Convert a time value to a date."""
        try:
            return (self.date(t) for t in value)
        except TypeError:
            pass

        kwargs = {self.time_units: value}
        return self.time_start + timedelta(**kwargs)

    @property
    def dates(self):
        """Convert the time axis to dates."""
        return list(self.date(self.time))

    def __getitem__(self, s):
        """Slices the box in the same way as you would slice data."""
        new_box = copy(self)

        if not isinstance(s, tuple):
            s = (s,)

        for q, t in zip(s, ['time', 'lat', 'lon']):
            setattr(new_box, t, getattr(self, t).__getitem__(s))

        return new_box

    @property
    def shape(self):
        """Get the shape of the box."""
        if not isinstance(self.time, np.ndarray):
            return (self.lat.size, self.lon.size)
        else:
            return (self.time.size, self.lat.size, self.lon.size)

    @property
    def rectangular(self):
        """Check wether the given latitudes and longitudes are linear, hence
        if the data is in geographic projection."""
        return is_linear(self.lat) and is_linear(self.lon)

    @property
    def resolution(self):
        """Gives the resolution of the box in units of years and km.
        The resolution of longitude is given as measured on the equator."""
        res_lat = np.abs(np.diff(self.lat[1:-1]).mean()) \
            * (np.pi / 180) * R_EARTH
        res_lon = np.abs(np.diff(self.lon[1:-1]).mean()) \
            * (np.pi / 180) * R_EARTH

        if isinstance(self.time, np.ndarray):
            res_time = np.diff(self.time[1:-1]).mean() * DAY
            return res_time, res_lat, res_lon
        else:
            return res_lat, res_lon

    @property
    def relative_grid_area(self):
        """Compute relative grid area of all pixels on the map."""
        lat_bnds = np.radians(self.lat_bnds)
        lon_bnds = np.radians(self.lon_bnds)
        delta_lat = (np.sin(lat_bnds[:, 1]) - np.sin(lat_bnds[:, 0])) / 2
        delta_lon = (lon_bnds[:, 1] - lon_bnds[:, 0]) / (2*np.pi)
        return delta_lon[None, :] * delta_lat[:, None]
