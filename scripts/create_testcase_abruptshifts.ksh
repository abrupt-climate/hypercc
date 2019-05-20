#!/bin/ksh



model="MIROC-ESM"

test=777 # number of the test, for historical reasons


### preparation

cdo setname,test${test} test1_Amon_${model}_rcp85_r1i1p1_200601-210012.nc test${test}_Amon_${model}_rcp85_r1i1p1_200601-210012.nc

cp test${test}_Amon_${model}_rcp85_r1i1p1_200601-210012.nc test${test}_Amon_${model}_piControl_r1i1p1_200601-210012.nc



## plotting in matlab

cat > create_testcase${test}.m << EOF

clear

%% just for the grid:
model='${model}';

%% read the field from nc file

varfile=netcdf.open(['test${test}_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc']); 
piCfile=netcdf.open(['test${test}_Amon_',model,'_piControl_r1i1p1_200601-210012.nc']); 

var_id=netcdf.inqVarID(varfile,'test${test}');
var(:,:,:)=netcdf.getVar(varfile,var_id);
var=double(var);


% determine dimensions
lons=size(var,1);
lats=size(var,2);
times=size(var,3);


rng('shuffle')

% initialise
climchange=zeros(lons,lats,times);
piControl=zeros(lons,lats,times);


yearvec=linspace(1,times/12,times);


 sigma=1;  
 

 %% create strong spatial edge around Southern Ocean:
 climchange(:,1:round(0.15*lats),:)=100;
 piControl(:,1:round(0.15*lats),:)=100;  % also put edge into piControl

 %% create local TP south of Equator at half the total time in rcp
 climchange(:,round(0.3*lats):round(0.5*lats),round(0.5*times):times)=3;


 % moving edge (moves from S to N):
 lat_tini=round((35+90)/180*lats);
 lat_tfin=round((75+90)/180*lats);

 value_north=-3;
 piControl(:,lat_tini:lats,:)=value_north;

 for timeind=1:times
   % lat_lower=floor(lat_tini+(lat_tfin-lat_tini)*timeind/times);
   % climchange(:,lat_lower:lats,timeind)=value_north;
   
   % % make it smoother
   lat_lower=lat_tini+(lat_tfin-lat_tini)*timeind/times;
   lat_lower_low=floor(lat_tini+(lat_tfin-lat_tini)*timeind/times);
   lat_lower_high=ceil(lat_tini+(lat_tfin-lat_tini)*timeind/times);

   frac=lat_lower-lat_lower_low;
   climchange(:,lat_lower_high+1:lats,timeind)=value_north;
   climchange(:,lat_lower_low,timeind) = value_north/2*(1-frac);
   climchange(:,lat_lower_high,timeind)= value_north/2*(1+frac);

 end


 noise_var=sigma*randn(lons,lats,times);
 noise_piControl=sigma*randn(lons,lats,times);
 climchange_nonoise=climchange;
 climchange=climchange+noise_var;
 climchange_zonmean=mean(climchange,1);
 piControl=piControl+noise_piControl;
 
 
 figure
 plot(yearvec,squeeze(climchange(1,round(0.4*lats),:)),'r')
 hold on
 plot(yearvec,squeeze(piControl(1,round(0.4*lats),:)),'Color',[0, 0.5, 0]) 
 hold on
 plot(yearvec,squeeze(climchange(1,round((55+90)/180*lats),:)),'b')
 legend('18S','18S, piControl','55N')
 xlabel('year')
 saveas(gcf,['test${test}_timeseries'],'pdf')
 
 
 figure
 contour(squeeze(climchange(10,:,:)))
 colormap(summer)
 colorbar
 %caxis([-5 5])

 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)

 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test777_time_vs_lat'],'pdf')
 


 figure
 contour(squeeze(climchange_nonoise(1,:,:)))
 colormap(summer)
 colorbar
 %caxis([-5 5])

 axtimestep=times/5;
 axlatstep=lats/6;
 set(gca,'XTick',1:axtimestep:times,'XTickLabel',2006:20:2100)
 set(gca,'YTick',1:axlatstep:lats,'YTickLabel',-90:30:90)

 ylabel('latitude')
 xlabel('year')
 saveas(gcf,['test777_time_vs_lat_nonoise'],'pdf')



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
 saveas(gcf,['test777_time_vs_lat_zonmean'],'pdf')


 
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

 saveas(gcf,['test777_piControl_time_vs_lat'],'pdf')
 

ncwrite(['test${test}_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc'],'test${test}',climchange)
ncwrite(['test${test}_Amon_',model,'_piControl_r1i1p1_200601-210012.nc'],'test${test}',piControl)

exit

EOF


matlab -nodesktop -nosplash -noFigureWindows -r create_testcase${test}




exit
