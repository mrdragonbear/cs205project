'''
This code converts the files in the mean_folder and anomaly_folder from NetCDF4 files to Zarr files
'''

import tqdm
import os
import glob
import xarray as xr

os.chdir("mean_folder")
for file in tqdm.tqdm(glob.glob("*.nc")):
    name = file.split('.')[0]
    xr.open_dataset(file).to_zarr(name,'w')
    os.remove(file)

os.chdir("../anomaly_folder")
for file in tqdm.tqdm(glob.glob("*.nc")):
    name = file.split('.')[0]
    xr.open_dataset(file).to_zarr(name,'w')
    os.remove(file)
