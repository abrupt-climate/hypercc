#!/bin/bash

./bin/hypercc \
    --data-folder ./data --output-folder ./treefrac-annual \
    report --model HadGEM2-ES \
    --variable treeFrac --scenario rcp85 --sigma-x 100 km --sigma-t 10 year \
    --annual \
    --lower-threshold pi-control-max*3/4
