#!/bin/ksh

## test 1
#varlist="intpp"
#monlist="4" # 1 4 7 10"
#modellist="NorESM1-ME"
#sigmaS=500
#sigmaT=10
#realm=ocean

#### test 2
#varlist="tas"
#monlist="3"
#modellist="MPI-ESM-LR"
#sigmaS=200
#sigmaT=10
#realm=atmosphere

#### test 3
#varlist="intpp"
#monlist="7"
#modellist="IPSL-CM5A-LR"
#sigmaS=200
#sigmaT=10
#realm=ocean

#### test 4
#varlist="mrso"
#monlist="7"
#modellist="CCSM4"
#sigmaS=200
#sigmaT=10
#realm=land



## scan automatically

### all models I ever found so far
modellist="ACCESS1-0 ACCESS1-3 bcc-csm1-1 bcc-csm1-1-m BNU-ESM CanAM4 CanCM4 CanESM2 CCSM4 CESM1-BGC CESM1-CAM5 CESM1-CAM5-1-FV2 CESM1-FASTCHEM CESM1-WACCM CFSv2-2011 CMCC-CESM CMCC-CM CMCC-CMS CNRM-CM5 CNRM-CM5-2 CSIRO-Mk3-6-0 CSIRO-Mk3L-1-2 EC-EARTH FGOALS-g2 FGOALS-gl FGOALS-s2 FIO-ESM GEOS-5 GFDL CM2p1 GFDL-CM3 GFDL-ESM2G GFDL-ESM2M GFDL-HIRAM-C180 GFDL-HIRAM-C360 GISS-E2-H GISS-E2-H-CC GISS-E2-R GISS-E2-R-CC HadCM3 HadGEM2-A HadGEM2-AO HadGEM2-CC HadGEM2-ES inmcm4 IPSL-CM5A-LR IPSL-CM5A-MR IPSL-CM5B-LR MIROC4h MIROC5 MIROC-ESM MIROC-ESM-CHEM MPI-ESM-LR MPI-ESM-MR MPI-ESM-P MRI-AGCM3-2H MRI AGCM3-2S MRI-CGCM3 MRI-ESM1 NICAM-09 NorESM1-M NorESM1-ME"


# selection for testing
modellist="ACCESS1-0 GFDL-CM3 MIROC-ESM HadGEM2-ES-CC MPI-ESM-MR EC-EARTH IPSL-CM5A-LR"

sigmaS=100
sigmaT=10


realm=atmosphere

## fast atm and land vars
varlist="  snw   lai  gpp npp rlus huss  prsn prw ps rlut rsut      snc snw   mrsos mrso rh ra fFire fVegLitter fVegSoil tran   snd mrro mrros nbp         rsds rlds  clt hurs hfss hfls rsus rlus pr prc tas tasmin tasmax sfcWind wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf alb cLitter"
monlist="1 4 7 10"





## slow land and atm vars,
#varlist="cSoil cVeg baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac"
#monlist="4"



# fast ocean vars

# slow ocean vars




## tier 1
#varlist="intpp omlmax sos tos treeFrac vegFrac tas tasmin tasmax    pr snw   lai  gpp npp cSoil cVeg rlus huss  prsn prw ps rlut rsut      snc snw         mrsos mrso rh ra fFire fVegLitter fVegSoil tran  snd mrro mrros nbp    sit sic      rsds rlds  clt hurs hfss hfls rsus rlus prc"

## tier 2 and 3
#varlist="sfcWind wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac alb cLitter              sim transix transiy        tos sos omldamax umo vmo mlotst pbo zos             chl dpco2 epc100 fgco2 intdic intpp o2min frc ph talk zooc zoocmisc bfe bsi calc co3 co3satcalc detoc dfe dissic dissoc dms pdo2 epcalc100 epfe100 epsi100 fddtalk fddtalk fddtdic fddtdife fddtdin fddtdop fddtdisi fgdms fgo2 dpo2 frc frfe frn fsfe intpbfe intpbsi intpcalc intpn2 no3 o2 phyc phyfe phyn phyp po4 pon pop sispco2 zo2min zsatcalc"


## all

#varlist="intpp sos tos treeFrac vegFrac tas tasmin tasmax    pr snw   lai  gpp npp cSoil cVeg rlus huss  prsn prw ps rlut rsut      snc snw         mrsos mrso rh ra fFire fVegLitter fVegSoil tran  snd mrro mrros nbp        sit sic      rsds rlds  clt hurs hfss hfls rsus rlus prc                                                                     sfcWind          wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac alb cLitter              sim transix transiy         omldamax omlmax umo vmo mlotst pbo zos             chl dpco2 epc100 fgco2 intdic intpp o2min frc ph talk zooc zoocmisc bfe bsi calc co3 co3satcalc detoc dfe dissic dissoc dms pdo2 epcalc100 epfe100 epsi100 fddtalk fddtalk fddtdic fddtdife fddtdin fddtdop fddtdisi fgdms fgo2 dpo2 frc frfe frn fsfe intpbfe intpbsi intpcalc intpn2 no3 o2 phyc phyfe phyn phyp po4 pon pop sispco2 zo2min zsatcalc  sfcWind sci rsdscs rldscs"



calc_new=0
logfile=1



### error check:

modellist="IPSL-CM5A-LR"
varlist=rsuscs
monlist="7"
calc_new=1
logfile=0




rea=r1i1p1
scen=rcp85
threshcase=2

outpath=/media/sf_D_DRIVE/datamining/edges/CMIP5scan


thresh1=pi-control-max

if [[ ${threshcase} == 2 ]]; then
 thresh2=pi-control-max*1/2
elif [[ ${threshcase} == 3 ]]; then
 thresh2=pi-control-3
elif [[ ${threshcase} == 4 ]]; then
 thresh2=pi-control-max*3/4
fi




for var in ${varlist}; do
for model in ${modellist}; do
for mon in ${monlist}; do

echo ""
echo "${var} ${model} ${scen} mon ${mon}"


# remove cache if too large
if [[ -f hypercc-cache.hdf5 ]]; then
  filesize=`du -k "hypercc-cache.hdf5" | cut -f1`
  if [[ ${filesize} -gt 100000 ]]; then
    echo "clearing cache..."
    rm hypercc-cache.hdf5 cache.lock hypercc-cache.db
  fi
fi



if [[ ! -f ${outpath}/logs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_log.txt || ${calc_new} == 1 ]]; then


## ocean (regridded)
if [[ ${realm} == ocean ]]; then

  extension="remapbilt100.nc"

  rcppath=/media/sf_D_DRIVE/CMIP5/data_duplicate
  piCpath=${rcppath}


  files_rcp=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.${extension} 2>/dev/null | wc -w `
  files_piC=`ls ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.${extension} 2>/dev/null | wc -w`

  if [[ ${files_rcp} -gt 0 && ${files_piC} -gt 0 ]]; then
    if [[ ${logfile} == 1 ]]; then
      mkdir -p ${outpath}/logs/${var}
      ./bin/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} --extension ${extension} --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} --lower-threshold ${thresh2}  > ${outpath}/logs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_log.txt
    else
      ./bin/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} --extension ${extension} --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} --lower-threshold ${thresh2} 
    fi
  fi
  ## optional:  --output-folder ${outpath}


  # land and atmo (not regridded)
elif [[ ${realm} == land || ${realm} == atmosphere ]]; then

  rcppath=/media/sf_W_DRIVE/PROJECTS/CMIP5data/modeldata/${model}/${scen}/${var}
  piCpath=/media/sf_W_DRIVE/PROJECTS/CMIP5data/modeldata/${model}/piControl/${var}


## for testing
#  rcppath=/media/sf_D_DRIVE/CMIP5/data_duplicate
#  piCpath=${rcppath}



  files_rcp=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc 2>/dev/null | wc -w`
  files_piC=`ls ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.nc 2>/dev/null | wc -w`
  if [[ ${files_rcp} -gt 0 && ${files_piC} -gt 0 ]]; then
    if [[ ${logfile} == 1 ]]; then
      mkdir -p ${outpath}/logs/${var}/
      ./bin/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} --lower-threshold ${thresh2} --sobel-scale 1 km/year > ${outpath}/logs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_log.txt
    else
      ./bin/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} --lower-threshold ${thresh2} --sobel-scale 1 km/year 
    fi
  fi



fi #calculate new




## select figures and put in 1 figure
##rm -f ${outpath}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}.png
if [[ ${files_rcp} -gt 0 && ${files_piC} -gt 0 ]]; then
  convert \( signal.png years.png regions.png -append \) \
  \( timeseries.png maxTgrad.png peakiness.png -append \) +append ${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}.png


  for type in signal years event_count regions peakiness maxTgrad timeseries; do
    mv ${type}.png ${outpath}/singlefigs/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_${type}.png 
  done

fi




fi # plot new

done #mon
done #model
done #var


exit
