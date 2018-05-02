#!/bin/bash

./bin/hypercc \
    --data-folder ./data --output-folder ./tas-mpi \
    report --model MPI-ESM-LR \
    --variable tas --scenario rcp85 --sigma-x 100 km --sigma-t 10 year \
    --month 03 \
    --lower-threshold pi-control-max*3/4
