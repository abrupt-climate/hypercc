
clear

%% just for the grid:
model='MIROC-ESM';

%% read the field from nc file

varfile=netcdf.open(['test4_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc']); 
piCfile=netcdf.open(['test4_Amon_',model,'_piControl_r1i1p1_200601-210012.nc']); 

var_id=netcdf.inqVarID(varfile,'test4');
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



 sigma=2;   %scale for global background noise (lat dependent)
 sigma_min=0.5 ; % (uniform)

 meanmax=20;
 jumpsize=10;

 %% background noise pattern: goes with sin(lat):
 for latind=1:lats
  noise_piControl(1:lons,latind,1:times)=(sigma_min+sigma*sin((latind-round(lats/2))/lats*pi))*randn(lons,1,times);
  noise_var(1:lons,latind,1:times)=(sigma_min+sigma*sin((latind-round(lats/2))/lats*pi))*randn(lons,1,times);
  meanval(1:lons,latind,1:times)=meanmax*cos((latind-round(lats/2))/lats*pi);
 end



%% tipping point around Equator

%% careful: the jump has to be bigger than local natural variability and smaller than high latitude variability 
%% *on the time scale of consideration* !!
%% here I use white noise on monthly data;
%% stdev scales with sqrt(N) => divide by sqrt(120) because there are 120 months in 10 years, then use 10yrs as smoothing time


 %% create local TP around Equator at half the total time in rcp
 jump=zeros(lons,lats,times);
 jump(:,round(0.4*lats):round(0.6*lats),round(sigma_min*times):times)=jumpsize*sigma_min/sqrt(120);


 climchange=noise_var+meanval+jump;
 piControl=noise_piControl+meanval;
 
 
 tropics=squeeze(climchange(1,round(lats/2),:));
 hilat=squeeze(climchange(1,lats,:));
 tropics_smoothed=movmean(tropics,120);
 hilat_smoothed=movmean(hilat,120);
 

 
 figure
 plot(yearvec,hilat)
 hold on
 plot(yearvec,tropics)
 xlabel('year')
 legend('high latitudes','tropics','Location', 'Best')
 saveas(gcf,['test4_timeseries'],'pdf')
 
 figure
 plot(yearvec,hilat_smoothed-mean(hilat_smoothed))
 hold on
 plot(yearvec,tropics_smoothed-mean(tropics_smoothed))
 xlabel('year')
 legend('high latitudes','tropics','Location', 'Best')
 saveas(gcf,['test4_timeseries_10yrsmoothed'],'pdf')
 
 figure
 contour(squeeze(climchange(1,:,:)))
 ylabel('latitude')
 xlabel('time')
 saveas(gcf,['test4_time_vs_lat'],'pdf')
 


ncwrite(['test4_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc'],'test4',climchange)
ncwrite(['test4_Amon_',model,'_piControl_r1i1p1_200601-210012.nc'],'test4',piControl)


