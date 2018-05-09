'''
SECTION 0 - DATASETS
(1) Observations: Download from ftp://ftp.cdc.noaa.gov/Datasets/gistemp/combsavetxt("times.csv",times,delimiter=",")ined/1200km/air.2x2.1200.mon.anom.comb.nc
(2) Models: Use the command aws s3 cp s3://nasanex/... ./
(3) Preprocessing:
'''
import tqdm
import os
import glob
import xarray as xr

os.chdir("/home/ubuntu/mean_folder")
for file in tqdm.tqdm(glob.glob("*.nc")):
    name = file.split('.')[0]
    xr.open_dataset(file).to_zarr(name,'w')
    os.remove(file)

os.chdir("/home/ubuntu/anomaly_folder")
for file in tqdm.tqdm(glob.glob("*.nc")):
    name = file.split('.')[0]
    xr.open_dataset(file).to_zarr(name,'w')
    os.remove(file)

######################################################################################################

import dask.array as da
import numpy as np
import dask, requests, csv
import netCDF4 as nc4
import time
from multiprocessing.pool import ThreadPool
from numpy import linalg as LA
from sklearn.preprocessing import Imputer
from scipy import stats
from numba import jit, prange
from dask.diagnostics import ProgressBar
from eofs.xarray import Eof

dask.set_options(pool=ThreadPool(8))
#dask.set_options(scheduler='threads')
dask.set_options(scheduler='processes')

num_workers = 8

def my_linregress(y):
    x = np.linspace(1,y.shape[0],y.shape[0])
    xd = x.astype(np.float32)
    sum_x = np.sum(xd)
    n = xd.size
    sum_xx = np.sum(xd**2)
    slopes = np.empty([y.shape[1],y.shape[2]])
    for i in range(y.shape[1]):
        for j in range(y.shape[2]):
            yd = y[:,i,j].astype(np.float32)
            sum_y = np.sum(yd)
            sum_xy = np.sum(xd*yd)
            sum_yy = np.sum(yd**2)
            slopes[i,j] = (sum_xy - (sum_x*sum_y)/n)/(sum_xx - (sum_x*sum_x)/n)
    return slopes

'''
SECTION 1 - OBSERVATIONAL DATA
(1) Access observational data.
(2) Perform linear regression on each data point, describing the temperature change of the data with respect to time. The slope of each linear regression is stored in the corresponding cell.
'''

start1 = time.time()

print('Setting up observational data...')	

os.chdir("/home/ubuntu/observations")
new = xr.open_dataset("observations.nc")
anomalies_obs = new.air[1320:1632,:,:]
anomalies_obs = anomalies_obs.reindex(lat=new['lat'],lon=new['lon'],method='nearest')
obs = anomalies_obs

anomaly_obs_slopes = np.zeros([anomalies_obs.lat.shape[0],anomalies_obs.lon.shape[0]])

anomalies_obs_da = da.from_array(anomalies_obs.data, chunks=[312,45,45])

anomaly_obs_slopes = da.map_blocks(my_linregress, anomalies_obs_da, dtype=np.ndarray,drop_axis=[0])

anomaly_obs_slopes = anomaly_obs_slopes.compute(num_workers = num_workers)

print('Linear regression slopes:')
print(anomaly_obs_slopes)
print('Units are temperature change for each data point in degrees/year.')

end1 = time.time()
section1 = end1 - start1
print(section1)

######################################################################################################

'''
SECTION 2 - COMPUTING MODEL MEAN (1950-1980)
(1) Access a folder with model temperature max and mins from 1950-1980.
(2) Compute the monthly mean over the period.
'''

start2 = time.time()

def monthly_mean_LEAP(X):
    time = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366]
    means = np.empty([12,X.shape[1],X.shape[2]])
    for t in range(12):
        means[t,:,:] = X[time[t]:time[t+1],:,:].mean(axis=0)
    return means

def monthly_mean_NOLEAP(X):
    time = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365]
    means = np.empty([12,X.shape[1],X.shape[2]])
    for t in range(12):
        means[t,:,:] = X[time[t]:time[t+1],:,:].mean(axis=0)
    return means

def monthly_std_LEAP(X):
    time = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366]
    stds = np.empty([12,X.shape[1],X.shape[2]])
    for t in range(12):
        stds[t,:,:] = X[time[t]:time[t+1],:,:].std(axis=0)
    return stds

def monthly_std_NOLEAP(X):
    time = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365]
    stds = np.empty([12,X.shape[1],X.shape[2]])
    for t in range(12):
        stds[t,:,:] = X[time[t]:time[t+1],:,:].std(axis=0)
    return stds

os.chdir("../mean_folder")
n = 0
for file in tqdm.tqdm(glob.glob("*")):
    ds = xr.open_zarr(file)
    ds.load()
    ds = ds.reindex(lat=obs['lat'], lon=obs['lon'], method='nearest')
    year = float(file.split("_")[6].split(".")[0])
    print(ds.values)
    if file.split("_")[0] == 'tasmax':
        if n == 0:
            average_temp = np.zeros([12, ds.lat.shape[0],ds.lon.shape[0]])    
        if np.mod(year, 4) == 0:
            temp_da = da.from_array(ds.tasmax.data, chunks=[366,45,45])
            temp = da.map_blocks(monthly_mean_LEAP, temp_da, dtype=np.ndarray)
        else:
            temp_da = da.from_array(ds.tasmax.data, chunks=[365,45,45])
            temp = da.map_blocks(monthly_mean_NOLEAP, temp_da, dtype=np.ndarray)
    else:
        if n == 0:
            average_temp = np.zeros([12, ds.lat.shape[0],ds.lon.shape[0]])
        if np.mod(year, 4) == 0:
            temp_da = da.from_array(ds.tasmin.data, chunks=[366,45,45])
            temp = da.map_blocks(monthly_mean_LEAP, temp_da, dtype=np.ndarray)
        else:
            temp_da = da.from_array(ds.tasmin.data, chunks=[365,45,45])
            temp = da.map_blocks(monthly_mean_NOLEAP, temp_da, dtype=np.ndarray)
    n += 1
    average_temp += temp.compute(num_workers = num_workers)

average_temp = average_temp/n

print(average_temp)
print(n)
print(average_temp.shape)

end2 = time.time()
section2 = end2 - start2
print(section2)
######################################################################################################

'''
SECTION 3 - COMPUTING MODEL ANOMALIES (1990-2015)
(1) Access a folder with model temperature max and mins from 1990-2015.
(2) Compute the monthly anomalies by subtracting the mean monthly temperatures over 1950-1980 from the monthly temepratures over 1990-2015.
'''
start3 = time.time()

os.chdir("/home/ubuntu/anomaly_folder")
i_max = 0
i_min = 0

for file in tqdm.tqdm(glob.glob("*")):
    ds = xr.open_zarr(file)
    ds.load()
    ds = ds.reindex(lat=obs['lat'],lon=obs['lon'],method='nearest')
    month_times = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    year = float(file.split("_")[6].split(".")[0])
    if file.split("_")[0] == 'tasmax':
        print(ds.tasmax.data)      
        if np.mod(year, 4) == 0:
            temp_da = da.from_array(ds.tasmax.data, chunks=[366,45,45])
            temp = da.map_blocks(monthly_mean_LEAP, temp_da, dtype=np.ndarray)
            temp_sd = da.map_blocks(monthly_std_LEAP, temp_da, dtype=np.ndarray)
        else:
            temp_da = da.from_array(ds.tasmax.data, chunks=[365,45,45])
            temp = da.map_blocks(monthly_mean_NOLEAP, temp_da, dtype=np.ndarray)
            temp_sd = da.map_blocks(monthly_std_NOLEAP, temp_da, dtype=np.ndarray)
        if i_max == 0:
            anomalies_max = xr.DataArray(temp.compute(num_workers = num_workers) - average_temp,coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            anomalies_max_sd = xr.DataArray(temp_sd.compute(num_workers = num_workers),coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            i_max += 1
        else:            
            anoms = xr.DataArray(temp.compute(num_workers = num_workers) - average_temp,coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            anomalies_max = xr.concat([anomalies_max,anoms],'time')
            anoms_sd = xr.DataArray(temp_sd.compute(num_workers = num_workers),coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            anomalies_max_sd = xr.concat([anomalies_max_sd,anoms_sd],'time')
    else:
        if np.mod(year, 4) == 0:
            temp_da = da.from_array(ds.tasmin.data, chunks=[366,45,45])
            temp = da.map_blocks(monthly_mean_LEAP, temp_da, dtype=np.ndarray)
            temp_sd = da.map_blocks(monthly_std_LEAP, temp_da, dtype=np.ndarray)
        else:
            temp_da = da.from_array(ds.tasmin.data, chunks=[365,45,45])
            temp = da.map_blocks(monthly_mean_NOLEAP, temp_da, dtype=np.ndarray)
            temp_sd = da.map_blocks(monthly_std_NOLEAP, temp_da, dtype=np.ndarray)
        if i_min == 0:
            anomalies_min = xr.DataArray(temp.compute(num_workers = num_workers) - average_temp,coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            anomalies_min_sd = xr.DataArray(temp_sd.compute(num_workers = num_workers),coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            i_min += 1
        else:
            anoms = xr.DataArray(temp.compute(num_workers = num_workers) - average_temp,coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            anomalies_min = xr.concat([anomalies_min,anoms],'time')
            anoms_sd = xr.DataArray(temp_sd.compute(num_workers = num_workers), coords=[month_times,ds.lat.data,ds.lon.data],dims  =['time','lat','lon'])
            anomalies_min_sd = xr.concat([anomalies_min_sd,anoms_sd],'time')

anomalies = (anomalies_max.sortby('time') + anomalies_min.sortby('time'))/2
time_months = np.linspace(1,len(anomalies['time']),len(anomalies['time']))
anomalies_sd = (anomalies_max_sd.sortby('time') + anomalies_min_sd.sortby('time'))/2

imp = Imputer(missing_values='NaN', strategy='mean', axis = 0)
for i in range(len(anomalies.time)):
    anomalies[i,:,:] = imp.fit_transform(anomalies[i,:,:])
    anomalies_obs[i,:,:] = imp.fit_transform(anomalies_obs[i,:,:])
print(anomalies)
print(anomalies_obs)
x = np.resize(anomalies.data[~np.isnan(anomalies_obs.data)],[-1,1])
y = np.resize(anomalies_obs.data[~np.isnan(anomalies.data)],[-1,1])
x1 = x[~np.isnan(x)]
y1 = y[~np.isnan(y)]

anomalies_corr = stats.pearsonr(x1,y1)
anomalies_ste = np.sum(np.square(x1 - y1))/(len(obs.time)*len(obs.lat)*len(obs.lon))
anomalies_sd_avg = np.mean(anomalies_sd)

print(anomalies)
print(anomalies_sd_avg)
print(anomalies_corr)
print(anomalies_ste)

end3 = time.time()
section3 = end3 - start3
print(section3)

######################################################################################################

'''
SECTION 4 - LINEAR REGRESSION ON THE ANOMALIES (1990-2015)
(1) Perform linear regression on the anomalies, describing the temperature change of the data with respect to time. The slope of each linear regression is stored in the corresponding cell.
'''

start4 = time.time()

anomalies_da = da.from_array(anomalies.data, chunks=[312,180,90])

anomaly_slopes = da.map_blocks(my_linregress, anomalies_da, dtype=np.ndarray,drop_axis=[0])

anomaly_slopes = anomaly_slopes.compute(num_workers = num_workers)

print(anomaly_slopes)

end4 = time.time()
section4 = end4 - start4
print(section4)

######################################################################################################

'''
SECTION 5 - PRINCIPAL COMPONENT ANALYSIS (1990-2015)
(1) Perform PCA on the observations and models.
(2) Compare to see differences
'''

start5 = time.time()

os.chdir("/home/ubuntu")
lon= 180
lat= 90
dim= lon * lat
months = 24

data = np.resize(x1,[dim,months])

solver = Eof(xr.DataArray(anomalies.data,dims=['time','lat','lon']))

pcs = solver.pcs(npcs=3, pcscaling=1)
eofs = solver.eofs(neofs=5, eofscaling=1)

variance_fractions = solver.varianceFraction()
variance_fractions = solver.varianceFraction(neigs=3)
print(variance_fractions)

myFile1 = open('PC1.csv', 'w')
with myFile1:
    writer = csv.writer(myFile1)
    writer.writerows(eofs[0,:,:].data)

myFile2 = open('PC2.csv', 'w')
with myFile2:
    writer = csv.writer(myFile2)
    writer.writerows(eofs[1,:,:].data)

myFile3 = open('PC3.csv', 'w')
with myFile3:
    writer = csv.writer(myFile3)
    writer.writerows(eofs[2,:,:].data)

myFile4 = open('anomalies.csv', 'w')
with myFile4:
    writer = csv.writer(myFile4)
    writer.writerows(anomalies[0,:,:].data)

end5 = time.time()

section5 = end5 - start5
print(section5)

######################################################################################################

'''
SECTION 6 - COMPUTING ANOMALY DIFFERENCE (1990-2015)
(1) Compute the difference between the observed and modelled anomalies.
(2) Save as a csv file.
'''
start6 = time.time()

anomalies_dif = anomaly_obs_slopes - anomaly_slopes

myFile = open('anomalies_dif.csv', 'w')
with myFile:
    writer = csv.writer(myFile)
    writer.writerows(anomalies_dif)

end6 = time.time()
section6 = end6 - start6
print(section6)

times = [section1, section2, section3, section4, section5, section6]
anomalies_sd_avg = np.float32(anomalies_sd_avg)
anomalies_corr = np.float32(anomalies_corr)[0]
taylor_diagram = [anomalies_sd_avg, anomalies_corr,  anomalies_ste]

np.savetxt("times.csv",times,delimiter=",")
np.savetxt("taylor_diagram.csv",taylor_diagram,delimiter=",", fmt='%s')
np.savetxt("fractions.csv",times,delimiter=",")
