#!/bin/ksh

### run as soon as all hrs6 files are available on Elements!

obsfolder=/media/bathiany/Elements/obsdata/qvi
here=/home/bathiany/Sebastian/datamining/edges/Abrupt/hypercc/evaluation/AtmosphericRivers

hrs6file1=adaptor.mars.internal-1576253834.6586642-6632-26-15bfdc33-a0e1-4e39-98a8-6502ad203897.nc
hrs6file2=adaptor.mars.internal-1576489315.6829126-21341-19-775c2d0d-2db4-4482-b96c-b5088c128f84.nc
hrs6file3=adaptor.mars.internal-1576588894.487814-10309-19-2a6c04a9-43b1-48e0-890a-cb8c9347fff6.nc
hrs6file4=adaptor.mars.internal-1576588959.7774909-32423-26-73e4c573-2fd7-43e5-b353-5c963f37e09b.nc
hrs6file5=adaptor.mars.internal-1576589007.2815864-8070-23-df7ea183-8d06-4c99-9807-729bfe64ff52.nc
hrs6file6=adaptor.mars.internal-1576589035.630861-7052-22-02c047a4-3805-4604-bb14-3ad72a984e4a.nc

cd ${obsfolder}


year=1998
while [[ ${year} -le 2008 ]]; do

  rm -f ERA5_qvi_Pacific_6hrs_?.nc
  cdo selyear,${year} -sellonlatbox,-170,-110,20,55 ${hrs6file1} ERA5_qvi_Pacific_6hrs_1.nc
  cdo selyear,${year} -sellonlatbox,-170,-110,20,55 ${hrs6file2} ERA5_qvi_Pacific_6hrs_2.nc
  cdo selyear,${year} -sellonlatbox,-170,-110,20,55 ${hrs6file3} ERA5_qvi_Pacific_6hrs_3.nc
  cdo selyear,${year} -sellonlatbox,-170,-110,20,55 ${hrs6file4} ERA5_qvi_Pacific_6hrs_4.nc
  cdo selyear,${year} -sellonlatbox,-170,-110,20,55 ${hrs6file5} ERA5_qvi_Pacific_6hrs_5.nc
  cdo selyear,${year} -sellonlatbox,-170,-110,20,55 ${hrs6file6} ERA5_qvi_Pacific_6hrs_6.nc


  rm -f ERA5_qvi_Pacific_hourly.nc
  cdo mergetime ERA5_qvi_Pacific_6hrs_?.nc ERA5_qvi_Pacific_hourly.nc
  rm ERA5_qvi_Pacific_6hrs_?.nc

  cdo -b f32 copy -setname,qvi -del29feb ERA5_qvi_Pacific_hourly.nc ERA5_qvi_Pacific_${year}_hourly.nc
  rm ERA5_qvi_Pacific_hourly.nc
  ncrename -d latitude,lat -v latitude,lat ERA5_qvi_Pacific_${year}_hourly.nc
  ncrename -d longitude,lon -v longitude,lon ERA5_qvi_Pacific_${year}_hourly.nc

  cdo splitmon ERA5_qvi_Pacific_${year}_hourly.nc ERA5_qvi_Pacific_${year}_hourly_

  (( year = ${year} + 1 ))
done


# cut original data into processable parts and prepare dummy files for python notebook to write out data

year=1998
while [[ ${year} -le 2008 ]]; do

  cdo selmon,1/4 ERA5_qvi_Pacific_${year}_hourly.nc ERA5_qvi_Pacific_hourly_${year}_01-04.nc
  cdo setname,outdata -mulc,0 ERA5_qvi_Pacific_hourly_${year}_01-04.nc dummy_hourly_${year}_01-04.nc

  cdo selmon,5/8 ERA5_qvi_Pacific_${year}_hourly.nc ERA5_qvi_Pacific_hourly_${year}_05-08.nc
  cdo setname,outdata -mulc,0 ERA5_qvi_Pacific_hourly_${year}_05-08.nc dummy_hourly_${year}_05-08.nc

  cdo selmon,9/12 ERA5_qvi_Pacific_${year}_hourly.nc ERA5_qvi_Pacific_hourly_${year}_09-12.nc
  cdo setname,outdata -mulc,0 ERA5_qvi_Pacific_hourly_${year}_09-12.nc dummy_hourly_${year}_09-12.nc

  (( year = ${year} + 1 ))
done







## create land-sea mask, East Pacific

lsmfile=ERA5_lsm.nc
cd /media/bathiany/Elements/obsdata/qvi
cdo sellonlatbox,-170,-110,20,55 ERA5_lsm.nc ERA5_lsm_Pacific.nc


exit

