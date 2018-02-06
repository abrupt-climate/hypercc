#!/bin/ksh

for test in 6; do


model=IPSL-CM5A-LR
#model=MIROC-ESM


cdo setname,test${test} test1_Amon_${model}_rcp85_r1i1p1_200601-210012.nc test${test}_Amon_${model}_rcp85_r1i1p1_200601-210012.nc
cp test${test}_Amon_${model}_rcp85_r1i1p1_200601-210012.nc test${test}_Amon_${model}_piControl_r1i1p1_200601-210012.nc


OIFS="$IFS"

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

EOF


if [[ ${test} == 1 ]]; then

cat >> create_testcase${test}.m << EOF


 %%% moving edge, starts at equator, moves linearly in time to North pole
 latc_ini=floor(lats/2);
 latc_fin=lats;

 for timeind=1:times
     lat_fin=floor(latc_ini+(latc_fin-latc_ini)*timeind/times);
     climchange(:,1:lat_fin,timeind)=1;
 end

 sigma=0.5;


 noise_var=sigma*randn(lons,lats,times);
 noise_piControl=sigma*randn(lons,lats,times);
 climchange=climchange+noise_var;
 piControl=piControl+noise_piControl;

EOF


elif [[ ${test} == 2 ]]; then

cat >> create_testcase${test}.m << EOF

 %%% 1 strong stationary spatial edge (only in rcp), one small (but locally very significant) tipping point

 %% create strong spatial edge around Southern Ocean:
 climchange(:,1:round(0.2*lats),:)=-100;

 %% create local TP around Equator at half the total time
 climchange(:,round(0.4*lats):round(0.6*lats),round(0.5*times):times)=2;
 
 sigma=1;

 noise_var=sigma*randn(lons,lats,times);
 noise_piControl=sigma*randn(lons,lats,times);
 climchange=climchange+noise_var;
 piControl=piControl+noise_piControl;

EOF


elif [[ ${test} == 3 ]]; then

cat >> create_testcase${test}.m << EOF
 %%% moving edge over latitudes,
 %% first 10 years and last 10 years are stationary.
 %% not Heaviside jump, but Gaussian peak with strong asymmetry (sigma differs between both sides).
 %% noise is small (but shall mask the smooth side of the function


 lon_ini=20*lons/360;           % round(lons/4)*(1-1/3);
 lon_fin=60*lons/360;  %round(lons/4)*(1+1/3);
 scale_short=7*lons/360;
 scale_long=100*lons/360;
 magnitude=1;
 timeini=120;
 timefin=times-120;
 
 scale_lat=lats/7;
 lat0=round(lats/2);

 for timeind=1:times

     if timeind < timeini
       position=lon_ini;
     elseif timeind > timefin
       position=lon_fin;       
     else
       position=lon_ini+(lon_fin-lon_ini)*(timeind-timeini)/(timefin-timeini);
     end
     
     for latind=1:lats

      weight_lat=cos((latind-lat0)/lats*pi)*exp(-((latind-lat0)^2)/(2*scale_lat^2));

      for lonind=1:lons
         if lonind < position
           climchange(lonind,latind,timeind)=magnitude*weight_lat*exp(-((lonind-position)^2)/(2*scale_short^2));
         else
           climchange(lonind,latind,timeind)=magnitude*weight_lat*exp(-((lonind-position)^2)/(2*scale_long^2));
         end
      end
    end
 end

sigma=0.5;


 noise_var=sigma*randn(lons,lats,times);
 noise_piControl=sigma*randn(lons,lats,times);
 climchange=climchange+noise_var;
 piControl=piControl+noise_piControl;



EOF


elif [[ ${test} == 4 ]]; then

cat >> create_testcase${test}.m << EOF


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
 saveas(gcf,['test${test}_timeseries'],'pdf')
 
 figure
 plot(yearvec,hilat_smoothed-mean(hilat_smoothed))
 hold on
 plot(yearvec,tropics_smoothed-mean(tropics_smoothed))
 xlabel('year')
 legend('high latitudes','tropics','Location', 'Best')
 saveas(gcf,['test${test}_timeseries_10yrsmoothed'],'pdf')
 
 figure
 contour(squeeze(climchange(1,:,:)))
 ylabel('latitude')
 xlabel('time')
 saveas(gcf,['test${test}_time_vs_lat'],'pdf')
 




EOF


elif [[ ${test} == 5 ]]; then

cat >> create_testcase${test}.m << EOF


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
 saveas(gcf,['test${test}_timeseries'],'pdf')
 
 
 figure
 contour(squeeze(climchange(1,:,:)))
 colorbar
 ylabel('latitude')
 xlabel('time')
 saveas(gcf,['test${test}_time_vs_lat'],'pdf')
 



EOF


elif [[ ${test} == 6 ]]; then

cat >> create_testcase${test}.m << EOF

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
 saveas(gcf,['test${test}_timeseries'],'pdf')


 sample_piControl_smoothed=movmean(sample_piControl,120);
 sample_climchange_smoothed=movmean(sample_climchange,120);

 figure
 plot(yearvec,sample_climchange)
 hold on 
 plot(yearvec,sample_piControl)
 xlabel('time')
 saveas(gcf,['test${test}_timeseries'],'pdf')


 figure
 plot(yearvec,sample_climchange_smoothed)
 hold on 
 plot(yearvec,sample_piControl_smoothed)
 xlabel('time')
 saveas(gcf,['test${test}_timeseries_runmean10yrs'],'pdf')


EOF
fi


cat >> create_testcase${test}.m << EOF
ncwrite(['test${test}_Amon_',model,'_rcp85_r1i1p1_200601-210012.nc'],'test${test}',climchange)
ncwrite(['test${test}_Amon_',model,'_piControl_r1i1p1_200601-210012.nc'],'test${test}',piControl)

exit

EOF

  matlab=/cygdrive/C/Program\ Files/MATLAB/R2016b/bin/win64/MATLAB.exe
  IFS=$'\n'
  ${matlab} -nodesktop -nosplash -minimize -noFigureWindows -r create_testcase${test}
 #${matlab} -r create_testcase${test}
  IFS="$OIFS" 


done #test

exit