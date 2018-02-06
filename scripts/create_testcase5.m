
clear

%% just for the grid:
model='MIROC-ESM';

%% read the field from nc file

varfile=netcdf.open(['test5_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc']); 
piCfile=netcdf.open(['test5_Amon_',model,'_piControl_r1i1p1_200601-210012.nc']); 

var_id=netcdf.inqVarID(varfile,'test5');
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



 %%% 1 strong stationary spatial edge (also in piControl), one small (but locally very significant) tipping point

 %% create strong spatial edge around Southern Ocean:
 climchange(:,1:round(0.2*lats),:)=100;
  piControl(:,1:round(0.2*lats),:)=100;  % also put edge into piControl

 %% create local TP around Equator at half the total time in rcp
 climchange(:,round(0.4*lats):round(0.6*lats),round(0.5*times):times)=2;
 
 sigma=1;

 noise_var=sigma*randn(lons,lats,times);
 noise_piControl=sigma*randn(lons,lats,times);
 climchange=climchange+noise_var;
 piControl=piControl+noise_piControl;

 
 figure
 plot(yearvec,squeeze(climchange(1,round(lats/2),:)))
 hold on
 plot(yearvec,squeeze(piControl(1,round(lats/2),:)))

 xlabel('year')
 saveas(gcf,['test5_timeseries'],'pdf')
 
 
 figure
 contour(squeeze(climchange(1,:,:)))
 colorbar
 ylabel('latitude')
 xlabel('time')
 saveas(gcf,['test5_time_vs_lat'],'pdf')
 



ncwrite(['test5_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc'],'test5',climchange)
ncwrite(['test5_Amon_',model,'_piControl_r1i1p1_200601-210012.nc'],'test5',piControl)


