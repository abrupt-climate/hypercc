#!/bin/bash

./bin/hypercc \
    --data-folder ../data/cmip5 --output-folder ./sic-$1 \
    report --model MPI-ESM-LR \
    --variable sic --scenario rcp85 --sigma-x 300 km --sigma-t 5 year \
    --month $1 \
    --lower-threshold pi-control-max*3/4 \
    --extension regrid.nc
