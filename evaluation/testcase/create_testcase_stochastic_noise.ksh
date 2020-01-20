#!/bin/ksh

### This script creates the netcdf data to run hypercc on the artificial test case.
### It also produces such files with the true edges (noise-free) as a ground truth for evaluating
# the performance of hypercc. The evaluation is done in the script edge_detection_eval.ksh


### name for grid (called model because can use CMIP5 grids)

#for model in r128x64 r240x120 r480x240; do
for model in r240x120; do

test=777 # number of the test, for historical reasons
for realization in r1i1p12 r1i1p13 r1i1p03; do

if [[ ! -f test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc ]]; then


output=png

### preparation

if [[ ${model} == MIROC-ESM || ${model} == CMCC-CM || ${model} == MPI-ESM-LR ]]; then
  cdo mergetime tas_orig_data/tas_Amon_${model}_rcp85_r1i1p1_??????-??????.nc \
                tas_Amon_${model}_rcp85_r1i1p1_200601-210012.nc

else
  cdo remapcon,${model} tas_orig_data/tas_Amon_MPI-ESM-LR_rcp85_r1i1p1_200601-210012.nc tas_Amon_${model}_rcp85_r1i1p1_200601-210012.nc

fi


 cdo selyear,2006/2100 -setlevel,0 -mulc,0 -setname,test${test} tas_Amon_${model}_rcp85_r1i1p1_200601-210012.nc \
                                             test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc
rm tas_Amon_${model}_rcp85_r1i1p1_200601-210012.nc

cp test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc \
   test${test}_Amon_${model}_piControl_${realization}_200601-210012.nc

# true edges
cp test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc \
   test${test}_Amon_${model}_rcp85_200601-210012_groundtruth.nc
cp test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc \
   test${test}_Amon_${model}_piControl_200601-210012_groundtruth.nc


if [[ ${realization} == r1i1p1 ]]; then
 sigma=1
elif [[ ${realization} == r1i1p12 ]]; then
 sigma=0.5
elif [[ ${realization} == r1i1p13 ]]; then
 sigma=3
elif [[ ${realization} == r1i1p0 ]]; then
 sigma=0.0000000001 #10^-10
elif [[ ${realization} == r1i1p01 ]]; then
 sigma=0.00001 #10^-5
elif [[ ${realization} == r1i1p02 ]]; then
 sigma=0.001 #10^-3
elif [[ ${realization} == r1i1p03 ]]; then
 sigma=0.1 
fi




## plotting in matlab

cat > create_testcase${test}.m << EOF

clear


%% read the field from nc file

varfile=netcdf.open(['test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc']); 

var_id=netcdf.inqVarID(varfile,'test${test}');
var(:,:,:)=netcdf.getVar(varfile,var_id);
var=double(var);


% determine dimensions
lons=size(var,1);
lats=size(var,2);
times=size(var,3);   %years*months (95*12)


rng('shuffle')

% initialise
climchange=zeros(lons,lats,times);
piControl=zeros(lons,lats,times);
edges_climchange=zeros(lons,lats,times);
edges_piControl=zeros(lons,lats,times);

yearvec=linspace(1,times/12,times);


 sigma=${sigma};
 

 value_SouthernOcean=100;
 value_Tropics=3;
 value_North=-3;

 %%%%%%%%%%%% edge 1: create strong spatial edge around Southern Ocean:
 climchange(:,1:round(0.15*lats),:)=value_SouthernOcean;
 climchange(:,round(0.15*lats)+1,:)=value_SouthernOcean/2;
 piControl(:,1:round(0.15*lats),:)=value_SouthernOcean; 
 piControl(:,round(0.15*lats)+1,:)=value_SouthernOcean/2; 

 %%% ground truth
 edges_climchange(:,round(0.15*lats)+1,:)=1;
 edges_piControl(:,round(0.15*lats)+1,:)=1;


 %%%%%%%%%%%% edge 3: create local TP south of Equator at half the total time in rcp

 climchange(:,round(0.3*lats):round(0.5*lats),round(0.5*times):times)=value_Tropics;
 climchange(:,round(0.3*lats):round(0.5*lats),round(0.5*times):times)=value_Tropics;

 climchange(:,round(0.3*lats)-1:round(0.5*lats)+1,round(0.5*times)-12:round(0.5*times)-1)=value_Tropics/2;

 %%% ground truth
 edges_climchange(:,round(0.3*lats)-1:round(0.5*lats)+1,round(0.5*times)-12:round(0.5*times)-1)=1;


 %%%%%%%%%%%% edge 4: spatial edge to North and South of the tipped area in tropics
 climchange(:,round(0.3*lats)-1,round(0.5*times)-12:times)=value_Tropics/2;
 climchange(:,round(0.5*lats)+1,round(0.5*times)-12:times)=value_Tropics/2;

 %%% ground truth
 edges_climchange(:,round(0.3*lats)-1,round(0.5*times)-12:times)=1;
 edges_climchange(:,round(0.5*lats)+1,round(0.5*times)-12:times)=1;




 %%%%%%%%%%% edge 2: moving edge (moves from S to N):
% lat_ini=round((35+90)/180*lats);
% lat_fin=round((75+90)/180*lats);
 lat_ini=round((36+90)/180*lats);
 lat_fin=round((72+90)/180*lats);


 %% piC edge (does not move)
 piControl(:,lat_ini:lats,:)=value_North;
 piControl(:,lat_ini-1,:)=value_North/2;
 % ground truth
 edges_piControl(:,lat_ini-1,:)=1;


%% 2-step transition in space. Makes it slow in time because 
%% the edge goes through more years than latitude steps.
%% This is due to the fact that grids typically have less latitude points in the give range than time points (years).
 for timeind=1:times
   lat_edge2=ceil(lat_ini+(lat_fin-lat_ini)*(timeind-1)/times);
   climchange(:,lat_edge2:lats,timeind)=value_North;
   climchange(:,lat_edge2-1,timeind)=value_North/2;
   edges_climchange(:,lat_edge2-1,timeind)=1;
 end


 % write the noise-free ground truth for later comparison
 ncwrite(['test${test}_Amon_${model}_rcp85_200601-210012_groundtruth.nc'],'test${test}',edges_climchange)
 ncwrite(['test${test}_Amon_${model}_piControl_200601-210012_groundtruth.nc'],'test${test}',edges_piControl)


 %% add the noise
 noise_var=sigma*randn(lons,lats,times);
 noise_piControl=sigma*randn(lons,lats,times);

 climchange=climchange+noise_var;
 climchange_zonmean=mean(climchange,1);

 piControl=piControl+noise_piControl;
 piControl_zonmean=mean(piControl,1);
 
 ncwrite(['test${test}_Amon_${model}_rcp85_${realization}_200601-210012.nc'],'test${test}',climchange)
 ncwrite(['test${test}_Amon_${model}_piControl_${realization}_200601-210012.nc'],'test${test}',piControl)



 %%% figures

 %%% time series
 figure
 plot(yearvec,squeeze(climchange(1,round(0.4*lats),:)),'r')
 hold on
 plot(yearvec,squeeze(piControl(1,round(0.4*lats),:)),'Color',[0, 0.5, 0]) 
 hold on
 plot(yearvec,squeeze(climchange(1,round((55+90)/180*lats),:)),'b')
 legend('18S','18S, piControl','55N')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_timeseries'],'${output}')



%%%% contour is not so good. smoothes ?!
%% maybe use imagesc(your_matrix)


 %%%%% Hovmöller: time vs latitude
 %% at one longitude
 figure
 contour(squeeze(climchange(1,:,:)))
 colormap(summer)
 colorbar
 %caxis([-5 5])
 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)
 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_climchange_time_vs_lat'],'${output}')

 %% zonal mean
 figure
 contour(squeeze(climchange_zonmean))
 colormap(summer)
 colorbar
 %caxis([-5 5])
 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)
 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_time_vs_lat_zonmean'],'${output}')

 %% at one latitude, piControl
 figure
 contour(squeeze(piControl(1,:,:)))
 colormap(summer)
 colorbar
 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)
 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_piControl_time_vs_lat'],'${output}')
 

 %% zonal mean, piControl
 figure
 contour(squeeze(piControl_zonmean))
 colormap(summer)
 colorbar
 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)
 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_piControl_time_vs_lat_zonmean'],'${output}')
 


 %% ground truth
 figure
 contour(squeeze(edges_climchange(1,:,:)))
 colormap(summer)
 colorbar
 %caxis([-5 5])
 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)
 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_climchange_time_vs_lat_edges_groundtruth'],'${output}')




 %% ground truth piControl
 figure
 contour(squeeze(edges_piControl(1,:,:)))
 colormap(summer)
 colorbar
 %caxis([-5 5])
 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)
 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test${test}_${model}_piControl_time_vs_lat_edges_groundtruth'],'${output}')



exit

EOF


matlab -nodesktop -nosplash -noFigureWindows -r create_testcase${test}

fi #new
done #model
done #rea

exit
