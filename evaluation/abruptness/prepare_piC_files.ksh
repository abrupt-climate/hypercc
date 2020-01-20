#!/bin/ksh

## used to prepare the piControl files that are then read in by abruptness_eval_piControl.py

cdo mergetime tas_Amon_MPI-ESM-LR_piControl_r1i1p1_??????-??????.nc \
              tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc

cdo selmon,4 tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1_mon4.nc
mv tas_Amon_MPI-ESM-LR_piControl_r1i1p1_mon4.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc


# now split again into chunks of 200 years length
cdo selyear,1850/2049 tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk1.nc
cdo selyear,2050/2249 tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk2.nc
cdo selyear,2250/2449 tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk3.nc
cdo selyear,2450/2649 tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk4.nc
cdo selyear,2650/2849 tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc tas_Amon_MPI-ESM-LR_piControl_r1i1p1_chunk5.nc

rm tas_Amon_MPI-ESM-LR_piControl_r1i1p1.nc



exit
