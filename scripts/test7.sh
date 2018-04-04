#!/bin/bash

./bin/hypercc \
    --data-folder ./data/testcases --output-folder ./test7 \
    report --model MIROC-ESM \
    --variable test7 --scenario rcp85 --sigma-x 300 km --sigma-t 3 year \
    --month 03 \
    --calibration-quartile max \
    --lower-threshold pi-control-max*1/2
