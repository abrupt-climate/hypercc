#!/bin/ksh

## purpose: scan CMIP5 archive automatically for abrupt shifts

### all models
modellist="ACCESS1-0 ACCESS1-3 bcc-csm1-1 bcc-csm1-1-m BNU-ESM CanAM4 CanCM4 CanESM2 CCSM4 CESM1-BGC CESM1-CAM5 CESM1-CAM5-1-FV2 CESM1-FASTCHEM CESM1-WACCM CFSv2-2011 CMCC-CESM CMCC-CM CMCC-CMS CNRM-CM5 CNRM-CM5-2 CSIRO-Mk3-6-0 CSIRO-Mk3L-1-2 EC-EARTH FGOALS-g2 FGOALS-gl FGOALS-s2 FIO-ESM GEOS-5 GFDL CM2p1 GFDL-CM3 GFDL-ESM2G GFDL-ESM2M GFDL-HIRAM-C180 GFDL-HIRAM-C360 GISS-E2-H GISS-E2-H-CC GISS-E2-R GISS-E2-R-CC HadCM3 HadGEM2-A HadGEM2-AO HadGEM2-CC HadGEM2-ES inmcm4 IPSL-CM5A-LR IPSL-CM5A-MR IPSL-CM5B-LR MIROC4h MIROC5 MIROC-ESM MIROC-ESM-CHEM MPI-ESM-LR MPI-ESM-MR MPI-ESM-P MRI-AGCM3-2H MRI AGCM3-2S MRI-CGCM3 MRI-ESM1 NICAM-09 NorESM1-M NorESM1-ME"



## variables

realm=atmosphere

## fast atm and land vars
varlist="  snw   lai  gpp npp rlus huss  prsn prw ps rlut rsut      snc snw   mrsos mrso rh ra fFire fVegLitter fVegSoil tran   snd mrro mrros nbp   rsds rlds  clt hurs hfss hfls rsus rlus pr prc tas tasmin tasmax sfcWind wap500 ci cltc clc cls clivi clwvi sci  rhs cct rldscs rlutcs rsdscs rsuscs    rsutcs tauu tauv ts uas vas      snm    rGrowth rMaint  tpf alb cLitter"
monlist="13 1 2 3 4 5 6 7 8 9 10 11 12"


## slow land vars
#varlist="cSoil cVeg baresoilFrac grassFrac treeFrac shrubFrac vegFrac treeFracPrimDec treeFracPrimEver treeFracPrimSecDec treeFracPrimSecEver burntArea c3PftFrac c4PftFrac"
#monlist="13"



#realm=ocean

## all ocean
#varlist="intpp tos sit sic sos sim transix transiy         omldamax omlmax umo vmo mlotst pbo zos             chl dpco2 epc100 fgco2 intdic intpp o2min frc ph talk zooc zoocmisc bfe bsi calc co3 co3satcalc detoc dfe dissic dissoc dms pdo2 epcalc100 epfe100 epsi100 fddtalk fddtalk fddtdic fddtdife fddtdin fddtdop fddtdisi fgdms fgo2 dpo2 frc frfe frn fsfe intpbfe intpbsi intpcalc intpn2 no3 o2 phyc phyfe phyn phyp po4 pon pop sispco2 zo2min zsatcalc"
monlist="13 1 2 3 4 5 6 7 8 9 10 11 12"

calc_new=1
write_logfile=1
sigmaS=100
sigmaTlist="10"
threshcaselist="2"



### tests for analysis

## a few selected models and months
#modellist="ACCESS1-0 MPI-ESM-LR MIROC-ESM GFDL-CM3"
#varlist="tas" # mrso snw frc fFire"
#monlist="1 4 7 10"
#threshcaselist="2"
#calc_new=1
#write_logfile=1
#sigmaTlist="10"

### one specific case: MPI04
modellist="MPI-ESM-LR"
varlist="tas"
monlist="4"
threshcaselist="2"
calc_new=1
write_logfile=1

### one specific case: ACCESS07
modellist="ACCESS1-0"
varlist="tas"
monlist="7"
threshcaselist="2"
calc_new=1
write_logfile=1

realm=atmosphere




rea=r1i1p1
scen=rcp85



outpath=~/Sebastian/datamining/edges/CMIP5scan
hyperccpath=~/Sebastian/datamining/edges/Abrupt/hypercc/bin

scriptpath=/home/sebastian/Abrupt/hypercc/scripts




rm -rf /home/bathiany/data_mounted_temp
ln -s /media/bathiany/'Seagate Expansion Drive' /home/bathiany/data_mounted_temp



for var in ${varlist}; do
for model in ${modellist}; do
for mon in ${monlist}; do
for sigmaT in ${sigmaTlist}; do
for threshcase in ${threshcaselist}; do

  
  ##  threshold values for hysteresis thresholding
  ### At the moment, no other choice than thresh1=pi-control-max is possible...
  
  ## pi-control-max refers to the maximum of the distribution from the sum of squared gradients.
  if [[ ${threshcase} == 2 ]]; then
   thresh1=pi-control-max
   thresh2=pi-control-max*1/2
  elif [[ ${threshcase} == 3 ]]; then
   thresh1=pi-control-max
   thresh2=pi-control-3
  elif [[ ${threshcase} == 4 ]]; then
   thresh1=pi-control-max
   thresh2=pi-control-max*3/4
  fi
  
  
  echo "${var} ${model} ${scen} mon ${mon}, sigmaT: ${sigmaT}, threshcase: ${threshcase}"
  
  logfile=${outpath}/logs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_log.txt
  
  checkfile=${logfile}
  #checkfile=${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}.png
  

  if [[ ! -f ${checkfile} || ${calc_new} == 1 ]]; then
    rm -f ${logfile}
    
    
    ## clear figures (now because needs to have enough time for new time stamp on files)
    mkdir -p ${outpath}/combifigs/${var}
    mkdir -p ${outpath}/singlefigs/${var}
    
    rm -f ${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}.png
    for type in signal years event_count regions peakiness maxTgrad kurtosis timeseries; do
      rm -f ${outpath}/singlefigs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_${type}.png
    done
    
    
    
    ### data paths and files
    
    #rcppath=/home/bathiany/data_mounted_temp/modeldata/${model}/${scen}/${var}
    #piCpath=/home/bathiany/data_mounted_temp/modeldata/${model}/piControl/${var}
    
    #### testing:
    rcppath=/home/bathiany/Sebastian/datamining/edges/testdata
    piCpath=/home/bathiany/Sebastian/datamining/edges/testdata
    
    
    count_files_rcp=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc 2>/dev/null | wc -w`
    count_files_piC=`ls ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.nc 2>/dev/null | wc -w`
    

    if [[ ${count_files_rcp} -gt 0 && ${count_files_piC} -gt 0 ]]; then
  
      if [[ ${write_logfile} == 1 ]]; then
        mkdir -p ${outpath}/logs/${var}
  
        echo "${var} ${model} ${scen} mon ${mon}, scales: ${sigmaT} years ${sigmaS} km, thresholds: ${thresh1} ${thresh2}" > ${logfile}
        echo ""
      fi
  
      echo ""
      echo "${var} ${model} ${scen} mon ${mon}, scales: ${sigmaT} year ${sigmaS} km, thresholds: ${thresh1} ${thresh2}"
  
      ## ocean (regridded)
      if [[ ${realm} == ocean ]]; then
    
        extension="remapbilt100.nc"
    
        ## if no regridded files are there, create them
    
        cd ${rcppath}
        count_files_rcp_regridded=`ls ${var}_*mon_${model}_${scen}_${rea}_??????-??????.${extension} 2>/dev/null | wc -w `
        if [[ ${count_files_rcp_regridded} -eq 0 ]]; then
          echo "regridding..."
          files_rcp=`ls ${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc 2>/dev/null`
          for file in ${files_rcp}; do
            basename=${file%??}
            if [[ ! -f ${basename}remapbilt100.nc ]]; then
              cdo -s remapbil,t100grid ${file} ${basename}remapbilt100.nc
            fi
          done
        fi
    
        cd ${piCpath}
        count_files_piC_regridded=`ls ${var}_*mon_${model}_piControl_${rea}_??????-??????.${extension} 2>/dev/null | wc -w`
        if [[ ${count_files_piC_regridded} -eq 0 ]]; then
          files_piC=`ls ${var}_*mon_${model}_piControl_${rea}_??????-??????.nc 2>/dev/null`
          for file in ${files_piC}; do
            basename=${file%??}
            if [[ ! -f ${basename}remapbilt100.nc ]]; then
              cdo -s remapbil,t100grid ${file} ${basename}remapbilt100.nc
            fi
          done
        fi
        cd ${scriptpath}
    
    
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
    
        ## optional:  --output-folder ${outpath}
    
  
  
  
      ### land and atmo (not regridded)
      elif [[ ${realm} == land || ${realm} == atmosphere ]]; then
    
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
    
        fi # write logfile
    
      fi #realm
  
  
      for type in maxTgrad abruptness; do    #event_count years 
        if [[ -f ${type}.txt || ${calc_new} == 1 ]]; then
          cp ${type}.txt ${outpath}/txtdata/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_${type}.txt
## Seb: change to mv again later
        fi
      done
    
    
    # save all single figures
      figfiles=0
      for type in signal years event_count regions maxTgrad timeseries abruptness scatter_abruptness scatter_year scatter_longitude scatter_latitude; do 
        if [[ -f ${type}.png || ${calc_new} == 1 ]]; then
          figfiles=1
          cp ${type}.png ${outpath}/singlefigs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_${type}.png
        fi
      done 
    
      ## select figures and put in one figure
      if [[ ${figfiles} == 1 ]]; then
        convert \( signal.png years.png abruptness.png -append \) \
        \( timeseries.png maxTgrad.png event_count.png  -append \) \
        +append ${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_maps_and_timeseries.png
    
        ## the 4 scatter plots
        convert \( scatter_abruptness.png scatter_year.png scatter_longitude.png scatter_latitude.png -append \) \
        +append ${outpath}/figs/${var}/${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}_scatterplots.png

# Seb: enable again later    
        # clean up
        #rm -f signal.png years.png event_count.png regions.png maxTgrad.png timeseries.png abruptness.png 
        #rm -f scatter_abruptness.png scatter_year.png scatter_longitude.png scatter_latitude.png
      fi
    
    else  # count files
      echo "no files found"
      #ls ${logfile}
      #rm -f ${logfile}
    fi
  
  
  fi # calc new
  


done # threshcase
done # sigmaT
done # mon

## delete regridded files due to disk space constraints
rm -f ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.${extension}
rm -f ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.${extension}

done # model
done # var

rm -rf /home/bathiany/data_mounted_temp

exit

