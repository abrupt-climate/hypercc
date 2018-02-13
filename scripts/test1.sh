#!/bin/bash

./bin/hypercc --data-folder ../data/cmip5/testcases report \
    --sigma-x 500 km --sigma-t 10 year \
    --model MIROC-ESM --variable test2 --scenario rcp85 --lower-threshold pi-control-max*3/4
