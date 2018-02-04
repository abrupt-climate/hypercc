"""
Implements serialisers for classes being used in the HyperCC workflow.
"""

import datetime
import argparse

from noodles import serial
from noodles.serial.numpy import arrays_to_hdf5

from .units import unit


class SerQuantity(serial.Serialiser):
    """Serialises a Pint Quantity."""
    def __init__(self):
        super().__init__('<pint.quantity>')

    def encode(self, obj, make_rec):
        return make_rec(str(obj))

    def decode(self, cls, data):
        return unit(data)


def quantity_hook(obj):
    """Pint Quantities are based on classes that cannot easily be
    imported, because they depend on a UnitRegistry. In our case
    this UnitRegistry is an instance residing in `hypercc.units`.
    This is why we need to catch Pint Quantities using a hook."""
    if isinstance(obj, unit.Quantity):
        return '<pint.quantity>'
    else:
        return None


class SerDateTime(serial.Serialiser):
    """Serialise a `datetime.datetime` object as an iso string."""
    def __init__(self):
        super().__init__(datetime.datetime)

    def encode(self, obj, make_rec):
        return make_rec(obj.isoformat())

    def decode(self, cls, data):
        return datetime.datetime.strptime(data, '%Y-%m-%dT%H:%M:%S')


class SerDate(serial.Serialiser):
    """Serialise a `datetime.date` as ordinal.
    (why is there no `strpdate`?)"""
    def __init__(self):
        super().__init__(datetime.date)

    def encode(self, obj, make_rec):
        return make_rec(obj.toordinal())

    def decode(self, cls, data):
        return datetime.date.fromordinal(data)


class SerNamespace(serial.Serialiser):
    """Serialise a `argparse.Namespace` object."""
    def __init__(self):
        super().__init__(argparse.Namespace)

    def encode(self, obj, make_rec):
        return make_rec(vars(obj))

    def decode(self, cls, data):
        return cls(**data)


def registry():
    return serial.Registry(
        parent=serial.base() + arrays_to_hdf5('hypercc-cache.hdf5'),
        types={
            argparse.Namespace: SerNamespace(),
            datetime.datetime: SerDateTime(),
            datetime.date: SerDate(),
            unit.Quantity: SerQuantity()
        },
        hooks={
            '<pint.quantity>': SerQuantity()
        },
        hook_fn=quantity_hook)
