
clear

%% just for the grid:
model='IPSL-CM5A-LR';

%% read the field from nc file

varfile=netcdf.open(['test6_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc']); 
piCfile=netcdf.open(['test6_Amon_',model,'_piControl_r1i1p1_200601-210012.nc']); 

var_id=netcdf.inqVarID(varfile,'test6');
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


 %%% red noise plus background trend (like global mean warming). No abrupt changes exist, apart from random shifts that are
 %% caused by superposition between background trend and climate variability.
 %% red noise and trend have the same parameters (spectrum) everywhere


 %%%% not really needed:
 %% due to smaller grid cells in high latitudes, weight variable with cos(lat). 
 % otherwise there will be large gradients due to spatially uncorrelated noise.


 sigma_var=1;
 alpha=0.7;


 noise_var=zeros(lons,lats,times);
 noise_piControl=zeros(lons,lats,times);

 %% red background spectrum

lat0=round(lats/2);
for latind=1:lats

 weight_lat=cos((latind-lat0)/lats*pi);
 sigma=sigma_var*sqrt((1-alpha^2))*weight_lat;

 noise_var(:,latind,1)=sigma*randn(lons,1,1);
 noise_piControl(:,latind,1)=sigma*randn(lons,1,1);
 for timeind=2:times
   noise_var(:,latind,timeind)=noise_var(:,latind,timeind-1)*alpha + sigma*randn(lons,1,1);
   noise_piControl(:,latind,timeind)=noise_piControl(:,latind,timeind-1)*alpha + sigma*randn(lons,1,1);
 end

end


 % trend;
 % can be interpreted as very large global warming over 100 years (in degree C):
 var_ini=15;
 var_fin=20;

 for timeind=1:times
   climchange(:,:,timeind) = var_ini + (var_fin-var_ini)*timeind/times;
 end

 climchange=climchange+noise_var;
 piControl=noise_piControl+var_ini;



 sample_climchange=squeeze(climchange(1,1,:));
 sample_piControl=squeeze(piControl(1,1,:));

 figure
 plot(yearvec,sample_climchange)
 hold on 
 plot(yearvec,sample_piControl)
 xlabel('time')
 saveas(gcf,['test6_timeseries'],'pdf')


 sample_piControl_smoothed=movmean(sample_piControl,120);
 sample_climchange_smoothed=movmean(sample_climchange,120);

 figure
 plot(yearvec,sample_climchange)
 hold on 
 plot(yearvec,sample_piControl)
 xlabel('time')
 saveas(gcf,['test6_timeseries'],'pdf')


 figure
 plot(yearvec,sample_climchange_smoothed)
 hold on 
 plot(yearvec,sample_piControl_smoothed)
 xlabel('time')
 saveas(gcf,['test6_timeseries_runmean10yrs'],'pdf')


ncwrite(['test6_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc'],'test6',climchange)
ncwrite(['test6_Amon_',model,'_piControl_r1i1p1_200601-210012.nc'],'test6',piControl)

exit

