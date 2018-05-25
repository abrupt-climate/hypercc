#!/bin/ksh

## scan automatically

### all models I ever found so far
modellist="ACCESS1-0 ACCESS1-3 bcc-csm1-1 bcc-csm1-1-m BNU-ESM CanAM4 CanCM4 CanESM2 CCSM4 CESM1-BGC CESM1-CAM5 CESM1-CAM5-1-FV2 CESM1-FASTCHEM CESM1-WACCM CFSv2-2011 CMCC-CESM CMCC-CM CMCC-CMS CNRM-CM5 CNRM-CM5-2 CSIRO-Mk3-6-0 CSIRO-Mk3L-1-2 EC-EARTH FGOALS-g2 FGOALS-gl FGOALS-s2 FIO-ESM GEOS-5 GFDL CM2p1 GFDL-CM3 GFDL-ESM2G GFDL-ESM2M GFDL-HIRAM-C180 GFDL-HIRAM-C360 GISS-E2-H GISS-E2-H-CC GISS-E2-R GISS-E2-R-CC HadCM3 HadGEM2-A HadGEM2-AO HadGEM2-CC HadGEM2-ES inmcm4 IPSL-CM5A-LR IPSL-CM5A-MR IPSL-CM5B-LR MIROC4h MIROC5 MIROC-ESM MIROC-ESM-CHEM MPI-ESM-LR MPI-ESM-MR MPI-ESM-P MRI-AGCM3-2H MRI AGCM3-2S MRI-CGCM3 MRI-ESM1 NICAM-09 NorESM1-M NorESM1-ME"



## selection for testing
#modellist="ACCESS1-0 GFDL-CM3 MIROC-ESM HadGEM2-ES-CC MPI-ESM-MR EC-EARTH IPSL-CM5A-LR"



# variables

realm=atmosphere

## fast atm and land vars
#varlist="  snw   lai  gpp npp rlus huss  prsn prw ps rlut rsut      snc snw   mrsos mrso rh ra fFire fVegLitter fVegSoil tran   snd mrro mrros nbp         rsds rlds  clt hurs hfss hfls rsus rlus pr prc tas tasmin tasmax sfcWind wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf alb cLitter"
#monlist="1 4 7 10"  # 1 3 5 7 9 11


## slow land and atm vars,
varlist="cSoil cVeg baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac"
monlist="13"







# fast ocean vars

# slow ocean vars





## tier 1
#varlist="intpp omlmax sos tos treeFrac vegFrac tas tasmin tasmax    pr snw   lai  gpp npp cSoil cVeg rlus huss  prsn prw ps rlut rsut      snc snw         mrsos mrso rh ra fFire fVegLitter fVegSoil tran  snd mrro mrros nbp    sit sic      rsds rlds  clt hurs hfss hfls rsus rlus prc"

## tier 2 and 3
#varlist="sfcWind wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac alb cLitter              sim transix transiy        tos sos omldamax umo vmo mlotst pbo zos             chl dpco2 epc100 fgco2 intdic intpp o2min frc ph talk zooc zoocmisc bfe bsi calc co3 co3satcalc detoc dfe dissic dissoc dms pdo2 epcalc100 epfe100 epsi100 fddtalk fddtalk fddtdic fddtdife fddtdin fddtdop fddtdisi fgdms fgo2 dpo2 frc frfe frn fsfe intpbfe intpbsi intpcalc intpn2 no3 o2 phyc phyfe phyn phyp po4 pon pop sispco2 zo2min zsatcalc"


## all

#varlist="intpp sos tos treeFrac vegFrac tas tasmin tasmax    pr snw   lai  gpp npp cSoil cVeg rlus huss  prsn prw ps rlut rsut      snc snw         mrsos mrso rh ra fFire fVegLitter fVegSoil tran  snd mrro mrros nbp        sit sic      rsds rlds  clt hurs hfss hfls rsus rlus prc                                                                     sfcWind          wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac alb cLitter              sim transix transiy         omldamax omlmax umo vmo mlotst pbo zos             chl dpco2 epc100 fgco2 intdic intpp o2min frc ph talk zooc zoocmisc bfe bsi calc co3 co3satcalc detoc dfe dissic dissoc dms pdo2 epcalc100 epfe100 epsi100 fddtalk fddtalk fddtdic fddtdife fddtdin fddtdop fddtdisi fgdms fgo2 dpo2 frc frfe frn fsfe intpbfe intpbsi intpcalc intpn2 no3 o2 phyc phyfe phyn phyp po4 pon pop sispco2 zo2min zsatcalc  sfcWind sci rsdscs rldscs"



calc_new=0
write_logfile=1
use_duplicate_data_fold=0


sigmaS=100
sigmaT=10




rea=r1i1p1
scen=rcp85
threshcase=2

outpath=/media/sf_D_DRIVE/datamining/edges/CMIP5scan
hyperccpath=/home/sebastian/Abrupt/hypercc/bin



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


# remove cache if too large (can also switch off cache in workflow.py)
if [[ -f hypercc-cache.hdf5 ]]; then
  filesize=`du -k "hypercc-cache.hdf5" | cut -f1`
  if [[ ${filesize} -gt 100000 ]]; then
    echo "clearing cache..."
    rm hypercc-cache.hdf5 cache.lock hypercc-cache.db
  fi
fi

logfile=${outpath}/logs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_log.txt

if [[ ! -f ${logfile} || ${calc_new} == 1 ]]; then



if [[ ${write_logfile} == 1 ]]; then
  mkdir -p ${outpath}/logs/${var}
  echo "${var} ${model} ${scen} mon ${mon}, scales: ${sigmaT} year ${sigmaS} km, thresholds: ${thresh1} ${thresh2}" > ${logfile}
  echo ""
fi

## clear figures (needs to have enough time for new time stamp)
mkdir -p ${outpath}/figs/${var}
rm -f ${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}.png
for type in signal years event_count regions peakiness maxTgrad timeseries; do
  rm -f ${outpath}/singlefigs/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_${type}.png 
done



## ocean (regridded)
if [[ ${realm} == ocean ]]; then

  extension="remapbilt100.nc"


if [[ ${use_duplicate_data_fold} == 1 ]]; then
   rcppath=/media/sf_D_DRIVE/CMIP5/data_duplicate
   piCpath=${rcppath}
else
  echo "need to choose data_duplicate folder for regridded files!"
  exit
fi


  files_rcp=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.${extension} 2>/dev/null | wc -w `
  files_piC=`ls ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.${extension} 2>/dev/null | wc -w`

  if [[ ${files_rcp} -gt 0 && ${files_piC} -gt 0 ]]; then
    rm -f ${logfile}

    echo ""
    echo "${var} ${model} ${scen} mon ${mon}, scales: ${sigmaT} year ${sigmaS} km, thresholds: ${thresh1} ${thresh2}"

    if [[ ${write_logfile} == 1 ]]; then
      if [[ ${mon} == 13 ]]; then
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --extension ${extension} --annual --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
          --upper-threshold ${thresh1} --lower-threshold ${thresh2}  \
          >> ${logfile}
      else
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --extension ${extension} --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
          --upper-threshold ${thresh1} --lower-threshold ${thresh2}  \
          >> ${logfile}
      fi #annual
    else
      if [[ ${mon} == 13 ]]; then
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath}  \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --extension ${extension} --annual --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
          --upper-threshold ${thresh1} --lower-threshold ${thresh2} 
      else
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath} \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --extension ${extension} --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
          --upper-threshold ${thresh1} --lower-threshold ${thresh2} 
      fi #annual
    fi
  else
    echo "no files found"
  fi
  ## optional:  --output-folder ${outpath}





  ### land and atmo (not regridded)
elif [[ ${realm} == land || ${realm} == atmosphere ]]; then

  rcppath=/media/sf_W_DRIVE/PROJECTS/CMIP5data/modeldata/${model}/${scen}/${var}
  piCpath=/media/sf_W_DRIVE/PROJECTS/CMIP5data/modeldata/${model}/piControl/${var}


## for testing
if [[ ${use_duplicate_data_fold} == 1 ]]; then
   rcppath=/media/sf_D_DRIVE/CMIP5/data_duplicate
   piCpath=${rcppath}
fi

  files_rcp=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc 2>/dev/null | wc -w`
  files_piC=`ls ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.nc 2>/dev/null | wc -w`
  if [[ ${files_rcp} -gt 0 && ${files_piC} -gt 0 ]]; then

    rm -f ${logfile}

    echo ""
    echo "${var} ${model} ${scen} mon ${mon}, scales: ${sigmaT} year ${sigmaS} km, thresholds: ${thresh1} ${thresh2}"

    if [[ ${write_logfile} == 1 ]]; then
      if [[ ${mon} == 13 ]]; then
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath} \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --annual --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} \
          --lower-threshold ${thresh2} --sobel-scale 1 km/year \
          >> ${logfile}
      else
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath} \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} \
          --lower-threshold ${thresh2} --sobel-scale 1 km/year \
          >> ${logfile}
      fi #annual


    else # no logfile
      if [[ ${mon} == 13 ]]; then
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath} \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --annual --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} \
          --lower-threshold ${thresh2} --sobel-scale 1 km/year 
      else
        ${hyperccpath}/hypercc --data-folder ${rcppath} --pi-control-folder ${piCpath} \
          report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
          --month ${mon} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km --upper-threshold ${thresh1} \
          --lower-threshold ${thresh2} --sobel-scale 1 km/year 
      fi #annual

    fi #logfile

  #else
   # echo "no files found"
  fi #files exist


fi #realm



## select figures and put in 1 figure

if [[ ${files_rcp} -gt 0 && ${files_piC} -gt 0 ]]; then

  figfiles=0
  for type in signal years event_count regions peakiness maxTgrad timeseries; do
    if [[ -f ${type}.png ]]; then
      figfiles=1
      cp ${type}.png ${outpath}/singlefigs/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_${type}.png 
    fi
  done

  if [[ ${figfiles} == 1 ]]; then
    convert \( signal.png years.png regions.png -append \) \
    \( timeseries.png maxTgrad.png peakiness.png -append \) \
    +append ${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}.png
    rm -f signal.png years.png event_count.png regions.png peakiness.png maxTgrad.png timeseries.png
  fi


fi #files are there, so rearrange plots



#else
#  echo "case done already"

fi # calc new

done #mon
done #model
done #var


exit



# test 1
#varlist="intpp"
#monlist="4" # 1 4 7 10"
#modellist="NorESM1-ME"
#sigmaS=500
#sigmaT=10
#realm=ocean

#### test 2
varlist="tas"
monlist="13"
modellist="MPI-ESM-LR"
sigmaS=200
sigmaT=10
realm=atmosphere
calc_new=1
logfile=0

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

varlist="tas"
monlist="1"
modellist="ACCESS1-3" 
sigmaS=100
sigmaT=10
realm=atmosphere
calc_new=1
logfile=0

### testing:
varlist="clwvi"
monlist="10"
modellist="CCSM4"
sigmaS=100
sigmaT=10
realm=atmosphere
calc_new=1
logfile=0


### testing:
varlist="prsn"
monlist="10"
modellist="ACCESS1-3"
sigmaS=100
sigmaT=10
realm=atmosphere
calc_new=1
logfile=0

varlist="gpp"
monlist="1"
modellist="CMCC-CESM"
sigmaS=100
sigmaT=10
realm=land
calc_new=1
logfile=0
use_duplicate_data_fold=1 

### testing:
varlist="rsuscs"
monlist="7"
modellist="IPSL-CM5A-LR"
sigmaS=100
sigmaT=10
realm=atmosphere
calc_new=1
logfile=0
