#!/bin/ksh

### How this script works:
# It runs the edge detection with hypercc, returns the mask of detected edges (as netcdf)
# Comparing to the generated ground truth of the testcase, it counts how many pixels are diagnosed correctly and how many are wrong
# It loops through different values for the lower threshold to produce a ROC curve

## The actual testcase has been produced in Matlab (no plots here - use create_testcase_abruptshift.ksh for these)

###### Before use, activate virtual env with python 3.5.6.
##############################################################################################################

## variable here stands for testcase ID
var=test777

#realizations="r1i1p03 r1i1p203"   #noise level 0.1
#realizations="r1i1p12 r1i1p212"      # noise level 0.5
realizations="r1i1p1 r1i1p21"   # noise level 1
#realizations="r1i1p13 r1i1p213"   ## noise level 3





Table=2

#arealist="North"
arealist="South"

if [[ ${Table} == 1 ]]; then
## Table with different smoothing scales
sigmaSlist="0 100 300 1000"
sigmaTlist="0 1 3 10"
frac_upper_list="1"
frac_lower=0.5

elif [[ ${Table} == 2 ]]; then
## Table with different f_u, f_l
frac_upper_list="1 0.5 0"
sigmaSlist="300"
sigmaTlist="10"
fi

# # # # # # # # # # # # #

ref_upper=max
ref_lower=max
calibration_quartile='max'


grid="r240x120"


for realization in ${realizations}; do
for area in ${arealist}; do
for sigmaS in ${sigmaSlist}; do
for sigmaT in ${sigmaTlist}; do
for frac_upper in ${frac_upper_list}; do


echo ""
echo "${grid}, ${realization}, sigmaT${sigmaT}, sigmaS${sigmaS}, ${frac_upper}piC${ref_upper}, ${area}"

if [[ ${Table} == 1 ]]; then
  cat new/ROC_${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_${frac_lower}piC${ref_lower}_${frac_upper}piC${ref_upper}_${area}.txt
elif [[ ${Table} == 2 ]]; then
  cat new_Tab2/ROC_${var}_${grid}_${realization}_sigmaT${sigmaT}_sigmaS${sigmaS}_frac_lower_piC${ref_lower}_${frac_upper}piC${ref_upper}_${area}.txt
fi


done #frac_upper 
done #sigmaS
done #sigmaT
done #area
done #rea

exit
