#!/usr/bin/env python3

"""
Setup script for the HyperCanny Climate module.
"""

from pathlib import Path
from setuptools import setup

# Get the long description from the README file
here = Path(__file__).parent.absolute()
with (here / 'README.rst').open(encoding='utf-8') as f:
    long_description = f.read()

setup(
    name='HyperCanny Climate module',
    version='0.1.0',
    description='Runs the Canny edge detector on climate data.',
    long_description=long_description,
    author='Johan Hidding',
    url='https://github.com/abrupt-climate/hypercc',
    packages=['hypercc'],
    classifiers=[
        'License :: OSI Approved :: Apache Software License',
        'Intended Audience :: Science/Research',
        'Environment :: Console',
        'Development Status :: 4 - Beta',
        'Programming Language :: Python :: 3.6'],
    install_requires=[
        'hyper_canny', 'noodles[numpy]', 'matplotlib', 'scipy', 'numpy',
        'netCDF4', 'jupyter', 'cartopy', 'pint'],
    extras_require={
        'develop': [
            'pytest', 'coverage', 'pep8', 'tox', 'flake8',
            'sphinx', 'sphinx_rtd_theme', 'nbsphinx'],
    },
)
