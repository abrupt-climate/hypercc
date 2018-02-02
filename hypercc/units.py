"""
Physical constants
"""

from pint import UnitRegistry
import locale

unit = UnitRegistry()

R_EARTH = 6.371e3 * unit.km
DAY = 0.0027378507871321013 * unit.year
MONTHS = [locale.nl_langinfo(getattr(locale, 'ABMON_{}'.format(i))).lower()
          for i in range(1, 13)]


def month_index(abname):
    """Get the index of the Month from the abbreviated name. The first month
    (that would be 'jan' in many locales) gives 0, moving up to 11 for
    december.

    :param abname: abbreviated name of the month.
    """
    return MONTHS.index(abname)
