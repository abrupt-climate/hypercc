#!/bin/bash

./bin/hypercc \
    --data-folder ../data/cmip5 report --model MPI-ESM-LR \
    --variable tas --scenario rcp85 --sigma-x 500 km --sigma-t 10 year \
    --month mar \
    --lower-threshold pi-control-max*3/4
