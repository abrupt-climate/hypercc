#!/bin/ksh

## purpose: scan CMIP5 archive automatically for abrupt shifts


## to save log, run with
# nohup ./scan_CMIP5.ksh >> log_scan_CMIP5.txt & tail -f log_scan_CMIP5.txt


###### all models for which there is at least one variable for piC and rcp85
modellist="BNU-ESM CanESM2 CCSM4 CESM1-BGC CESM1-CAM5 CESM1-CAM5-1-FV2 CMCC-CESM CMCC-CMS CNRM-CM5 CSIRO-Mk3-6-0 EC-EARTH FGOALS-g2 FIO-ESM GFDL-CM3 GFDL-ESM2G GFDL-ESM2M GISS-E2-H GISS-E2-H-CC GISS-E2-R GISS-E2-R-CC HadGEM2-CC HadGEM2-ES inmcm4 IPSL-CM5A-LR IPSL-CM5A-MR IPSL-CM5B-LR MIROC5 MIROC-ESM MIROC-ESM-CHEM MPI-ESM-LR MPI-ESM-MR MRI-CGCM3 NorESM1-M NorESM1-ME     bcc-csm1-1  CMCC-CM ACCESS1-0 ACCESS1-3  bcc-csm1-1-m"



####### variables
#realm=atmosphere
#varlist="rlus huss prw ps rlut rsut rsds rlds clt hurs hfss hfls rsus pr prc tas tasmin tasmax sfcWind ci clivi clwvi sci rldscs rlutcs rsdscs rsuscs tauu tauv ts uas vas     prsn cct"

## fast land vars (or land ice)
#realm=land
#varlist="gpp npp nbp snc snw snm mrsos mrso mrro mrros rh ra tran fFire fVegLitter fVegSoil rGrowth rMaint lai"


### slow land vars
#realm=land
#varlist="cSoil cVeg baresoilFrac grassFrac treeFrac"
#monlist="13"

## all ocean (and ocean ice)
#realm=ocean
#varlist="intpp tos sit sic sos snd  omlmax mlotst pbo zos chl dpco2 epc100 fgco2 intdic frc ph talk zooc zoocmisc"



#monlist="1 2 3 4 5 6 7 8 9 10 11 12"




## testcase
realm=atmosphere
modellist="MPI-ESM-LR"
monlist="4"
varlist="tas"




##### repair
#varlist="cct ci clivi clt clwvi hfls hfss hurs huss prc pr prsn prw ps rldscs rlds rlus rlutcs rlut rsdscs rsds rsuscs rsus rsut sci sfcWind tasmax tasmin tas tauu tauv ts uas vas"
#realm=atmosphere
#modellist="GISS-E2-R"
#monlist="1 2 3 4 5 6 7 8 9 10 11 12"




######## settings
calc_new=1

write_logfile=1
sigmaSlist="100"
sigmaTlist="10"
threshcaselist="2"




rea=r1i1p1
scen=rcp85

outpath=~/Sebastian/datamining/edges/CMIP5scan
hyperccpath=~/Sebastian/datamining/edges/Abrupt/hypercc/bin
scriptpath=`pwd`   ## this folder


## options: single or parallel; month selection; grid selection
option_single="--single"


if [[ ! -d /home/bathiany/data_mounted_temp ]]; then
  ln -s /media/bathiany/'Seagate Expansion Drive' /home/bathiany/data_mounted_temp
fi


#### clean up


figure_list="signal years_maxabrupt event_count event_count_timeseries regions maxTgrad timeseries abruptness scatter_abruptness scatter_year scatter_longitude scatter_latitude"

outdata_maps_list="event_count maxTgrad years_maxabrupt abruptness"



for var in ${varlist}; do
for model in ${modellist}; do

### clear cache - otherwise it fills the whole hard drive...
rm -f hypercc-cache.hdf5 cache.lock hypercc-cache.db

for sigmaT in ${sigmaTlist}; do
for sigmaS in ${sigmaSlist}; do
for threshcase in ${threshcaselist}; do
for mon in ${monlist}; do

  if [[ ${mon} == 13 ]]; then
    option_month="--annual"
  else
    option_month="--month ${mon}"
  fi

  basename=${var}_${model}_${scen}_${rea}_mon${mon}_sigmaT${sigmaT}_sigmaS${sigmaS}_lowthreshcase${threshcase}

  
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
  
  echo ""
  echo "${var} ${model} ${scen} mon ${mon}, sigmaT: ${sigmaT}, sigmaS: ${sigmaS}, threshcase: ${threshcase}"
  date

  logfile=${outpath}/logs/${var}/${basename}_log.txt
  

  ### remove old logfiles from previous erroneous runs:
  ### Will only be recalculated if checkfile=${logfile} below!!
  if [[ -f ${logfile} && ${calc_new} == 0 ]]; then
    loglines=`cat ${logfile} |wc -l`
    if [[ ${loglines} -lt 2 ]]; then
      echo "Error: logfile is empty. Removing logfile..."
      rm -f ${logfile}
    fi
  fi


  checkfile=${logfile}
  ##checkfile=${outpath}/figs_combi/${var}/${basename}_maps.png
  ##checkfile=${outpath}/outdata/${var}/${basename}_abruptness.nc

  if [[ ! -f ${checkfile} || ${calc_new} == 1 ]]; then
    rm -f ${logfile}
    
        
    ####################
    #########   preparation: files and paths
    ####################
    ## remove local figures to avoid that old ones are used and wrongly labeled:
    for figure in ${figure_list}; do 
      rm -f ${figure}.png
    done
    
    ## remove local outdata files
    for data in ${outdata_maps_list}; do 
      rm -f ${data}.nc
    done
    rm -f dummy.nc

    ## prepare folders
    mkdir -p ${outpath}/figs_combi/${var}
    mkdir -p ${outpath}/figs_single/${var}
    mkdir -p ${outpath}/logs/${var}
    mkdir -p ${outpath}/outdata/${var}


    ## clear figures in destination folders 
    ## (already at this point because needs to have enough time for new time stamp on files)
    rm -f ${outpath}/figs_combi/${var}/${basename}_*.png
    rm -f ${outpath}/figs_single/${var}/${basename}_*.png

    ## clear outdata in folders
    rm -f ${outpath}/outdata/${var}/${basename}_*.*


    #################################### preparation: input and output data  ###################
    ####################################

    ### set paths for data paths    
    rcppath=/home/bathiany/data_mounted_temp/modeldata/${model}/${scen}/${var}
    piCpath=/home/bathiany/data_mounted_temp/modeldata/${model}/piControl/${var}


    count_files_rcp=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc 2>/dev/null | wc -w`
    count_files_piC=`ls ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.nc 2>/dev/null | wc -w`

     
    if [[ ${count_files_rcp} -gt 0 && ${count_files_piC} -gt 0 ]]; then

      if [[ ${write_logfile} == 1 ]]; then
        echo "${var} ${model} ${scen} mon ${mon}, scales: ${sigmaT} years ${sigmaS} km, thresholds: ${thresh1} ${thresh2}" > ${logfile}
        echo ""
      fi
      
 
      ########### remapping grids when needed and applying land-sea mask
      ##########################################


      ########################### 
      ######### 1. regrid files with curvilinear grids
      ###################################
      
      extension=""
      option_extension=""


      if [[ ( ( ${realm} == "ocean" ) && ( ! ${model} == GISS-E2-H-CC ) && ( ! ${model} == GISS-E2-R-CC ) ) ||  ${model} == FGOALS-g2 ]]; then

        # FGOALS only has unexpected grid (also for atmosphere), CESM1.--- has only ocean output
        # here, regrid both on a lonlat grid with similar size than native grids:
        if [[ ${model} == "FGOALS-g2" || ${model} == "CESM1-CAM5-1-FV2" ]]; then
          gridres=80
          extension="_remapbilt${gridres}"
          option_extension="--extension nc${extension}"
          grid=t${gridres}grid

        else   # remap on atmos/land grid
          extension="_remap2atmosgrid"
          option_extension="--extension nc${extension}"
  
          grid=/home/bathiany/Sebastian/CMIP5/landseamask/atmosgrid_${model}.nc
         
          if [[ ! -f ${grid} ]]; then
            echo "error: no atmos grid found to project on. abort."
            exit
          fi 
        fi
    
        cd ${piCpath}
        echo "regridding piControl files to grid: ${grid}..."
        files_piC=`ls ${var}_*mon_${model}_piControl_${rea}_??????-??????.nc 2>/dev/null`
        for file in ${files_piC}; do
          if [[ ! -f ${file}${extension} ]]; then
            cdo -s remapbil,${grid} ${file} ${file}${extension}
          fi
        done

        cd ${rcppath}        
        echo "regridding rcp files to grid: ${grid}..."
        files_rcp=`ls ${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc 2>/dev/null`
        for file in ${files_rcp}; do
          if [[ ! -f ${file}${extension} ]]; then
            cdo -s remapbil,${grid} ${file} ${file}${extension}
          fi
        done


      fi #regrid



      ########################### 
      ######### 2. apply land-sea mask
      ###################################

      lsm_path=/home/bathiany/Sebastian/CMIP5/landseamask

      if [[ ${realm} == "land" ]]; then
        lsmfile=${lsm_path}/sftlf_fx_${model}_rcp85_r0i0p0_binary.nc
      elif [[ ${realm} == "ocean" ]]; then   # inverse mask
        lsmfile=${lsm_path}/sftlf_fx_${model}_rcp85_r0i0p0_inverse_binary.nc
      fi
      if [[ ${model} == "FGOALS-g2" ]]; then  # this model had a mask but this was regridded like the data
        if [[ ${realm} == "land" ]]; then
          lsmfile=${lsm_path}/sftlf_fx_FGOALS-g2_rcp85_r0i0p0_remapbilt80_binary.nc
        elif [[ ${realm} == "ocean" ]]; then   # inverse mask
          lsmfile=${lsm_path}/sftlf_fx_FGOALS-g2_rcp85_r0i0p0_remapbilt80_inverse_binary.nc
        fi
      fi

      ## check if lsm exists and if realm is not atmosphere:
      if [[ -f ${lsmfile} && ! ${realm} == atmosphere ]]; then

        ## check if masking is needed (i.e. variable not masked in file already):
        masking=0
        for path in ${rcppath} ${piCpath}; do
          cd ${path}

          ## check if masking is needed by investigating first file only
          ## (Files have been checked and repaired so that this is sufficient for all models and variables)
          ### use original files for this check, not the remapped ones because remapping ocean to atmos grid leads to misvals         
          files=`ls ${var}_*mon_${model}_*_${rea}_??????-??????.nc 2>/dev/null`
          for file in ${files}; do
            cdo -s seltimestep,1 ${file} ${file}_step1
            count=`cdo -s info ${file}_step1 | cut -c48-63`
            misvals=`echo ${count} | cut -c12`
            rm ${file}_step1
            break
          done

          if [[ ${misvals} == 0 ]]; then
            masking=1
          fi
        done #path

        if [[ ${masking} == 1 ]]; then
          echo "             There are no missing values - apply mask to file..."
          for path in ${rcppath} ${piCpath}; do
            cd ${path}
            files=`ls ${var}_*mon_${model}_*_${rea}_??????-??????.nc${extension} 2>/dev/null`
            for file in ${files}; do
              cdo -s ifthen ${lsmfile} ${file} ${file}_masked
            done # file  
          done #path (rcp, piC)



          ### add this flag to the file name hypercc looks for, and remove the intermediary files

          if [[ ! ${extension} == "" ]]; then
            rm -f ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.nc${extension}
            rm -f ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc${extension}
          fi

          extension="${extension}_masked"
          option_extension="--extension nc${extension}"

        fi # apply mask
      fi   # mask



      cd ${scriptpath}


      ############### provide a dummy file for writing outdata:
      #######################################################
      files=`ls ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc${extension} 2>/dev/null`
      for file in ${files}; do
        cp ${file} dummy.nc
        break 
      done

      if [[ ! -f dummy.nc ]]; then
        echo "Error: dummy file is missing. something went wrong."
        exit
      fi
      cdo -s seltimestep,1 -setname,outdata dummy.nc dummy2.nc
      cdo -s mulc,0 dummy2.nc dummy.nc
      rm dummy2.nc
      for data in ${outdata_maps_list}; do
        cp dummy.nc ${data}.nc
      done



      ###########  run the edge detector   
      ############################################
      if [[ ${write_logfile} == 1 ]]; then
          ${hyperccpath}/hypercc ${option_single} --data-folder ${rcppath} --pi-control-folder ${piCpath}  \
            report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
            ${option_extension} ${option_month} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
            --upper-threshold ${thresh1} --lower-threshold ${thresh2} ${option_logfile} \
            >> ${logfile}
      else
          ${hyperccpath}/hypercc ${option_single} --data-folder ${rcppath} --pi-control-folder ${piCpath} \
            report --variable ${var} --model ${model} --scenario ${scen} --realization ${rea} \
            ${option_extension} ${option_month} --sigma-t ${sigmaT} year --sigma-x ${sigmaS} km \
            --upper-threshold ${thresh1} --lower-threshold ${thresh2}
      fi




      ############  clean up figures and outdata
      ##################################################

      ## only save figures and outdata if log is longer than the first line, and if calibration is not above threshold:
      loglines=`cat ${logfile} |wc -l`
      abortmessage=`cat ${logfile} | grep "* ValueError: Maximum signal below calibration limit, no need to continue." |wc -w`
            
      if [[ ${loglines} > 1 && ${abortmessage} == 0 ]]; then
      
        ## outdata files for maps and ts
        
        mkdir -p ${outpath}/outdata/${var}
        for data in ${outdata_maps_list}; do
          if [[ -f ${data}.nc ]]; then
            cp ${data}.nc ${outpath}/outdata/${var}/${basename}_${data}.nc
          fi
        done
        if [[ -f event_count_timeseries.txt ]]; then
          cp event_count_timeseries.txt ${outpath}/outdata/${var}/${basename}_event_count_timeseries.txt
        fi
        
      
        ### save all single figures
        figfiles=0
        for figure in ${figure_list}; do  
          if [[ -f ${figure}.png ]]; then
            figfiles=1
            cp ${figure}.png ${outpath}/figs_single/${var}/${basename}_${figure}.png
          fi
        done
      
      
        ## select figures and put in combined figures
        if [[ ${figfiles} == 1 ]]; then
      
          ## the 4 maps
          convert \( event_count.png abruptness.png  -append \) \
          \(  years_maxabrupt.png maxTgrad.png -append \) \
          +append ${outpath}/figs_combi/${var}/${basename}_maps.png
      
          ## the 3 time series
          convert \( signal.png timeseries.png event_count_timeseries.png -append \) \
          +append ${outpath}/figs_combi/${var}/${basename}_timeseries.png
      
          ## the 4 scatter plots
          convert \( scatter_abruptness.png scatter_year.png -append \) \
          \( scatter_longitude.png scatter_latitude.png -append \) \
          +append ${outpath}/figs_combi/${var}/${basename}_scatterplots.png
      
        fi
      fi ## logfile countains output  


      if [[ ${loglines} -lt 2 ]]; then
        echo "Something did not work. logfile is empty. Removing logfile..."
      fi

    else  # count files
      echo "no files found"
    fi
  
  
  fi # calc new
  

done # mon
done # threshcase
done # sigmaT
done # sigmaS


### delete regridded files due to disk space constraints
if [[ ! ${extension} == "" ]]; then
  rm -f ${piCpath}/${var}_*mon_${model}_piControl_${rea}_??????-??????.nc${extension}
  rm -f ${rcppath}/${var}_*mon_${model}_${scen}_${rea}_??????-??????.nc${extension}
fi

done # model
done # var

##rm -rf /home/bathiany/data_mounted_temp

exit

