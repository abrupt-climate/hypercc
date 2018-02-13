#!/bin/bash

./bin/hypercc \
    --data-folder ../data/cmip5 --output-folder ./pr-$1 \
    report --model HadGEM2-ES \
    --variable pr --scenario rcp85 --sigma-x 500 km --sigma-t 10 year \
    --month $1 \
    --lower-threshold pi-control-max*3/4
