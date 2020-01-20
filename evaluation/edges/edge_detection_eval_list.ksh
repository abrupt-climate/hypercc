#!/bin/ksh

### How this script works:
# It runs the edge detection with hypercc, returns the mask of detected edges (as netcdf)
# Comparing to the generated ground truth of the testcase, it counts how many pixels are diagnosed correctly and how many are wrong
# It loops through different values for the lower threshold to produce a ROC curve

## The actual testcase has been produced in Matlab (no plots here - use create_testcase_abruptshift.ksh for these)

###### Before use, activate virtual env with python 3.5.6.

## This script was generated to produce the table with the TPR and FPR results when varying the smoothing scales

##############################################################################################################

## variable here stands for testcase ID
var=test777

calc_new=1

realizations="r1i1p1 r1i1p21 r1i1p12 r1i1p03 r1i1p212 r1i1p203"
frac_upper="1"
frac_lower="0.5"
sigmaSlist="0 100 300 1000"
sigmaTlist="0 1 3 10"


#sigmaSlist="300"
#sigmaTlist="10"

# # # # # # # # # # # # #

ref_upper=max
ref_lower=max
calibration_quartile='max'

arealist="North South"

grid="r240x120" 
mon=4

#################################################################
########################################################
for realization in ${realizations}; do

for sigmaS in ${sigmaSlist}; do
for sigmaT in ${sigmaTlist}; do


ROCfilename=ROC_${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_${frac_lower}piC${ref_lower}_${frac_upper}piC${ref_upper}


if [[ ! -f ${ROCfilename}_South.txt || ${calc_new} == 1 ]]; then

if [[ ! -f ${var}_Amon_${grid}_rcp85_${realization}_200601-210012.nc ]]; then 
  echo "file not found"
  exit
fi



cat > ${ROCfilename}.py << EOF
import numpy as np
import netCDF4

TP=0
FN=0
FP=0
TN=0

EOF

for area in ${arealist}; do
cat >> ${ROCfilename}.py << EOF
TPR_${area}=0.0
FPR_${area}=0.0
EOF
done





rm -f hypercc-cache.hdf5 cache.lock hypercc-cache.db

  basename=${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_${frac_lower}piC${ref_lower}_${frac_upper}piC${ref_upper}


    echo ""
    echo "${var}, ${grid}, ${realization}, scales: ${sigmaT} years,  ${sigmaS} km, thresholds: ${frac_lower}*piC${ref_lower}, ${frac_upper}*piC${ref_upper}"
    date

      ############### provide a dummy file for writing outdata:
      cdo -s mulc,0 -selmon,${mon} -setname,outdata ${var}_Amon_${grid}_rcp85_${realization}_200601-210012.nc dummy3d.nc
      cdo seltimestep,1 dummy3d.nc dummy2d.nc
      for data in event_count maxTgrad years_maxabrupt abruptness; do
        cp dummy2d.nc ${data}.nc
      done
      rm dummy2d.nc
      
      mv dummy3d.nc edge_mask_detected.nc
      
      ###########  run the edge detector
          ~/Sebastian/datamining/edges/Abrupt/hypercc/bin/hypercc --single  \
            report --variable ${var} --model ${grid} --scenario rcp85 --realization ${realization} \
            --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
            --upper-threshold-ref pi-control-${ref_upper} --lower-threshold-ref pi-control-${ref_lower} \
            --upper-threshold-frac ${frac_upper} --lower-threshold-frac ${frac_lower} \
            --calibration-quartile "${calibration_quartile}"
      
    echo ""




###### now make the assessment   
   
 
# depending on timescale, remove ends:
(( yfin = 2100 - 2 * ${sigmaT} ))
(( yini = 2006 + 2 * ${sigmaT} ))
cdo setlevel,0 -setname,${var} edge_mask_detected.nc ${basename}_edge_mask_detected.nc
cdo selyear,${yini}/${yfin} ${basename}_edge_mask_detected.nc ${basename}_edge_mask_detected_core.nc


cp ${var}_Amon_${grid}_rcp85_200601-210012_groundtruth.nc thetruth.nc


## remove ends here as well
cdo selyear,${yini}/${yfin} -selmon,${mon} thetruth.nc thetruth_core.nc

cdo mulc,2 thetruth_core.nc thetruth_core_mulc2.nc
cdo sub thetruth_core_mulc2.nc ${basename}_edge_mask_detected_core.nc ${basename}_error.nc



for area in ${arealist}; do

# create area from arealist
if [[ ${area} == global ]]; then
  cp ${basename}_error.nc ${basename}_error_global.nc 
elif [[ ${area} == North ]]; then
  cdo sellonlatbox,-180,180,10,90 ${basename}_error.nc ${basename}_error_North.nc
elif [[ ${area} == South ]]; then
  if [[ ${grid} == r128x64 ]]; then
    cdo selindexbox,1,128,21,30 ${basename}_error.nc ${basename}_error_South.nc
  elif [[ ${grid} == r240x120 ]]; then
    cdo selindexbox,1,240,39,57 ${basename}_error.nc ${basename}_error_South.nc
  elif [[ ${grid} == r480x240 ]]; then
    cdo selindexbox,1,480,76,116 ${basename}_error.nc ${basename}_error_South.nc
  else
    echo "define tropical TP area (South) on this grid"
    exit
  fi
fi


## now read file in python
# and populate the vector for the looped parameter

cat >> ${ROCfilename}.py << EOF

# read the netcdf
ncfile1 = netCDF4.Dataset("${basename}_error_${area}.nc", "r", format="NETCDF4")
error = ncfile1.variables['${var}'][:,:,:]


# count each class:
TP=np.count_nonzero(error == 1)
FN=np.count_nonzero(error == 2)
FP=np.count_nonzero(error == -1)
TN=np.count_nonzero(error == 0)

TPR_${area}=TP/(TP+FN)
FPR_${area}=FP/(FP+TN)



EOF


done #area

rm ${basename}_error.nc
rm ${basename}_edge_mask_detected.nc
rm ${basename}_edge_mask_detected_core.nc







###### output of results for all frac_lower and areas
for area in ${arealist}; do


rm -f ${ROCfilename}_${area}.txt
cat >> ${ROCfilename}.py << EOF


file2write=open("${ROCfilename}_${area}.txt",'w')


file2write.write(str('{0:1.2f}'.format(TPR_${area})) + ' (' + str('{0:1.2e}'.format(FPR_${area})) + ')' + '\n')



file2write.close()


EOF


done #area



python ${ROCfilename}.py
rm ${ROCfilename}.py


for area in ${arealist}; do
  cp ${ROCfilename}_${area}.txt new
  rm ${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_${frac_lower}piC${ref_lower}_${frac_upper}piC${ref_upper}_error_${area}.nc
done #area


fi #new


done #sigmaS
done #sigmaT

# clean up
rm -f thetruth.nc thetruth_core.nc thetruth_core_mulc2.nc
rm -f hypercc-cache.hdf5 cache.lock hypercc-cache.db
figure_list="signal years_maxabrupt event_count event_count_timeseries regions maxTgrad timeseries abruptness scatter_abruptness scatter_year scatter_longitude scatter_latitude"
for figure in ${figure_list}; do
  rm -f ${figure}.png
done
rm -f maxTgrad.nc abruptness.nc years_maxabrupt.nc event_count.nc event_count_timeseries.txt


done  #realization

exit
