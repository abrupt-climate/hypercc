#!/bin/ksh

### How this script works:
# It runs the edge detection with hypercc, returns the mask of detected edges (as netcdf)
# Comparing to the generated ground truth of the testcase, it counts how many pixels are diagnosed correctly and how many are wrong
# It loops through different values for the lower threshold to produce a ROC curve

## The actual testcase has been produced in Matlab (no plots here - use create_testcase_abruptshift.ksh for these)

###### Before use, activate virtual env with python 3.5.6.


## used to generate values for Table in article

##############################################################################################################

## variable here stands for testcase ID
var=test777

calc_new=1

#realizations="r1i1p12 r1i1p03 r1i1p212 r1i1p203"
#frac_upper_list="1 0.1 0.01 0.001 0.0001 0" 
#sigmaSlist="1000 300 100 0"
#sigmaTlist="10 3 1 0"

realizations="r1i1p1 r1i1p21 r1i1p12 r1i1p03 r1i1p212 r1i1p203"
frac_upper_list="1 0.5 0"  
sigmaSlist="300"
sigmaTlist="10"

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

for frac_upper in ${frac_upper_list}; do

if [[ ${frac_upper} == 1 ]]; then
  frac_lower_list="1 0.5 0"     #1 0.1 0.01 0.001 0.0001 0" 
elif [[ ${frac_upper} == 0.5 ]]; then
  frac_lower_list="0.5 0"
elif [[ ${frac_upper} == 0.1 ]]; then
  frac_lower_list="0.1 0.01 0.001 0.0001 0" 
elif [[ ${frac_upper} == 0.01 ]]; then
  frac_lower_list="0.01 0.001 0.0001 0" 
elif [[ ${frac_upper} == 0.001 ]]; then
  frac_lower_list="0.001 0.0001 0"
elif [[ ${frac_upper} == 0.0001 ]]; then
  frac_lower_list="0.0001 0"
elif [[ ${frac_upper} == 0 ]]; then
  frac_lower_list="0"
fi





ROCfilename=ROC_${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_frac_lower_piC${ref_lower}_${frac_upper}piC${ref_upper}


if [[ ! -f ${ROCfilename}_South.txt || ${calc_new} == 1 ]]; then

if [[ ! -f ${var}_Amon_${grid}_rcp85_${realization}_200601-210012.nc ]]; then 
  echo "file not found"
  exit
fi

### count how many lower frac values there are
frac_lower_steps=0      
for frac_lower in ${frac_lower_list}; do
  (( frac_lower_steps = ${frac_lower_steps} + 1 ))
done #frac_lower



cat > ${ROCfilename}.py << EOF
import numpy as np
import netCDF4

params=${frac_lower_steps}

frac_lower_vec=np.zeros(params)

TP=np.zeros(params, dtype=int)
FN=np.zeros(params, dtype=int)
FP=np.zeros(params, dtype=int)
TN=np.zeros(params, dtype=int)

EOF

for area in ${arealist}; do
cat >> ${ROCfilename}.py << EOF
TPR_${area}=np.zeros(params)
FPR_${area}=np.zeros(params)
EOF
done


#rm -f hypercc-cache.hdf5 cache.lock hypercc-cache.db

frac_lower_index=0      # index that runs up to total number of lower thresholds 
for frac_lower in ${frac_lower_list}; do

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


###### define what the "truth" is against which results are compared
## no, rcp85 is already the truth... comment out
#cdo sub ${var}_Amon_${grid}_rcp85_200601-210012_groundtruth.nc ${var}_Amon_${grid}_piControl_200601-210012_groundtruth.nc thetruth.nc

#cdo setlevel,0 thetruth.nc thetruth_lev0.nc
#mv thetruth_lev0.nc thetruth.nc

cp ${var}_Amon_${grid}_rcp85_200601-210012_groundtruth.nc thetruth.nc


## remove ends here as well
cdo selyear,${yini}/${yfin} -selmon,${mon} thetruth.nc thetruth_core.nc


## calculate the error
## this now distinguishes different errors as follows
# true positives: 1
# true negatives: 0
# false positives: -1
# false negatives: 2
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


frac_lower_vec[${frac_lower_index}]=${frac_lower}

# count each class:
TP[${frac_lower_index}]=np.count_nonzero(error == 1)
FN[${frac_lower_index}]=np.count_nonzero(error == 2)
FP[${frac_lower_index}]=np.count_nonzero(error == -1)
TN[${frac_lower_index}]=np.count_nonzero(error == 0)


print(TP)
print(FP)
print(TN)
print(FN)

TPR_${area}[${frac_lower_index}]=TP[${frac_lower_index}]/(TP[${frac_lower_index}]+FN[${frac_lower_index}])
FPR_${area}[${frac_lower_index}]=FP[${frac_lower_index}]/(FP[${frac_lower_index}]+TN[${frac_lower_index}])


EOF


done #area

rm ${basename}_error.nc
rm ${basename}_edge_mask_detected.nc
rm ${basename}_edge_mask_detected_core.nc


  (( frac_lower_index = ${frac_lower_index} + 1 ))
done #frac_lower





###### output of results for all frac_lower and areas
for area in ${arealist}; do


rm -f ${ROCfilename}_${area}.txt
cat >> ${ROCfilename}.py << EOF

#np.set_printoptions(precision=3)


format_f = "{:.2f}".format
format_e = "{:.2e}".format


#print('${area}')
#print(frac_lower_vec)
#np.set_printoptions(formatter={'float_kind':format_f})
#print(TPR_${area})
#np.set_printoptions(formatter={'float_kind':format_e})
#print(FPR_${area})


### save these values and the fractions for lower thresh in a file

file2write=open("${ROCfilename}_${area}.txt",'w')
file2write.write('lower_frac: ' + str(frac_lower_vec)+ '\n')
#file2write.write('TPR:' + str('{0:1.2f}'.format(TPR_${area})) + '\n')
#file2write.write('FPR:' + str('{0:1.2e}'.format(FPR_${area})) + '\n')
#file2write.write(str(TPR_${area}) + ' (' + str(FPR_${area}) + ')' + '\n')

np.set_printoptions(formatter={'float_kind':format_f})
file2write.write('TPR:' + str(TPR_${area}) + '\n')
np.set_printoptions(formatter={'float_kind':format_e})
file2write.write('FPR:' + str(FPR_${area}) + '\n')

file2write.close()


EOF


done #area



python ${ROCfilename}.py
#rm ${ROCfilename}.py

for area in ${arealist}; do
  cp ${ROCfilename}_${area}.txt new_Tab2
  for frac_lower in ${frac_lower_list}; do
    rm ${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_${frac_lower}piC${ref_lower}_${frac_upper}piC${ref_upper}_error_${area}.nc
  done 
done

fi #new

done #frac_upper 
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
