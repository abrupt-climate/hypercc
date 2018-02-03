"""
Functionality for reading and interpreting single NetCDF files.
"""

from datetime import date

import netCDF4
from pyparsing import Word, Suppress, Group, tokenMap, alphas, nums
import numpy as np


def parse_time_units(units):
    """Parse time unit string from a NetCDF file. Such a string may look like::

        "<unit> since <date>"

    where ``<date>`` looks like::

        "<year>-<month>-<day>"

    Returns: 2-tuple (unit string, datetime object)
    """
    p_int = Word(nums).setParseAction(tokenMap(int))
    p_date = Group(p_int('year') + Suppress('-') +
                   p_int('month') + Suppress('-') +
                   p_int('day'))('date').setParseAction(
                       tokenMap(lambda args: date(*args)))
    p_time_unit = Word(alphas)('units') + Suppress("since") + p_date
    result = p_time_unit.parseString(units)
    return result['units'], result['date'][0]


class File(object):
    """Interface to single NetCDF4 file with bounds set on the time.

    Rationale: When we load a set of datafiles from a time series,
    sometimes the times may overlap. In this case we may set the
    ``bounds`` property in this object to limit data to the needed time slots.
    Combining the limited datasets will result in a a nice contiguous dataset.
    """
    def __init__(self, f):
        self.path = f
        # pylint: disable=E1101
        self.data = netCDF4.Dataset(f, 'r', format='NETCDF4')
        self.bounds = slice(None)

    @property
    def time(self):
        """Returns the time variable restricted to the given bounds."""
        return self.data.variables['time'][self.bounds]

    @property
    def lat(self):
        """Returns the latitudes of the grid."""
        return self.data.variables['lat'][:]

    @property
    def lon(self):
        """Returns the longitudes of the grid."""
        return self.data.variables['lon'][:]

    @property
    def lat_bnds(self):
        """Returns the latitude intervals of the grid."""
        return self.data.variables['lat_bnds'][:]

    @property
    def lon_bnds(self):
        """Returns the longitude intervals of the grid."""
        return self.data.variables['lon_bnds'][:]

    def get(self, var):
        """Get the values of a given variable limited to the time bounds set.
        """
        return self.data.variables[var][self.bounds]

    def get_masked(self, var):
        """The NetCDF file may specify a floating point value for missing
        values, for instance in the case of variables that only have valid
        entries on sea or land cells. In this case we'd like to obtain a
        masked array in stead of a normal ndarray object.

        This function returns a masked array for the given variable. When no
        mask is needed, a normal numpy array is returned.
        """
        data = self.data.variables[var][self.bounds]
        missing_value = self.data.variables[var].missing_value
        masked_data = np.ma.masked_equal(data, missing_value)
        if masked_data.mask is np.ma.nomask:
            return masked_data.data
        else:
            return masked_data

    @property
    def time_units(self):
        """Obtain time units from the NetCDF"""
        dt, t0 = parse_time_units(self.data.variables['time'].units)
        return dt, t0
