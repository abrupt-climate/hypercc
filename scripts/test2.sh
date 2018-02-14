#!/bin/bash

./bin/hypercc --data-folder ../data/cmip5 report --model HadGEM2-ES --variable mrso --scenario rcp85 --sigma-x 500 km --sigma-t 10 year --month 3
