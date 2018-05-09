#!/bin/bash

#Model names and numbers from ProjectCode_Master.sh for reference
#model = {"inmc4": 1, "bcc-csm1-1": 2, "NorESM1-M": 3, "MRI-CGCM3": 4, "MPI-ESM-MR": 5, "MPI-ESM-LR": 6, "MIROC5": 7, "MIROC-ESM":8 , "MIROC-ESM-CHEM": 9, "IPSL-CM5A-MR": 10, "CCSM4": 11, "BNU-ESM": 12, "ACCESS1-0": 13, "GFDL-ESM2G": 14, "GFDL-CM3": 15, "CanESM2": 16, "CSIRO-Mk3-6-0": 17, "CNRM-CM5": 18, "CESM1-BGC": 19, "MRI-CGCM3": 20, "GFDL-ESM2M": 21}

echo " Model  $1 being run.."

echo "Downloading GISS surface temperature observation data.."

# Download observational data
#mkdir observations
#wget ftp://ftp.cdc.noaa.gov/Datasets/gistemp/combined/1200km/air.2x2.1200.mon.anom.comb.nc
#mv air.2x2.1200.mon.anom.comb.nc ~/observations/observations.nc

echo "Downloading 1950-1980 model temperature data from s3://nasanex/NEX-GDDP/ into home/ubuntu/mean_folder"

aws s3 cp s3://nasanex/NEX-GDDP/BCSD/historical/day/atmos/tasmin/r1i1p1/v1.0/ /home/ubuntu/mean_folder/ --recursive --exclude "*" --include "*$1*" --exclude "*1981*" --exclude "*1982*" --exclude "*1983*" --exclude "*1984*" --exclude "*1985*" --exclude "*1986*" --exclude "*1987*" --exclude "*1988*" --exclude "*1989*" --exclude "*200*" --exclude "*199*" --exclude "*.json" --exclude "*.json*"
aws s3 cp s3://nasanex/NEX-GDDP/BCSD/historical/day/atmos/tasmax/r1i1p1/v1.0/ /home/ubuntu/mean_folder/ --recursive --exclude "*" --include "*$1*" --exclude "*1981*" --exclude "*1982*" --exclude "*1983*" --exclude "*1984*" --exclude "*1985*" --exclude "*1986*" --exclude "*1987*" --exclude "*1988*" --exclude "*1989*" --exclude "*200*" --exclude "*199*" --exclude "*.json" --exclude "*.json*"

echo "Downloading 1990-2005 model temperature data from s3://nasanex/NEX-GDDP/ into /home/ubuntu/anomaly_folder"

aws s3 cp  s3://nasanex/NEX-GDDP/BCSD/historical/day/atmos/tasmax/r1i1p1/v1.0/ /home/ubuntu/anomaly_folder/ --recursive --exclude "*" --include "*$1*" --exclude "*198*" --exclude "*197*" --exclude "*196*" --exclude "*195*" --exclude "*.json" --exclude "*.json*"
aws s3 cp  s3://nasanex/NEX-GDDP/BCSD/historical/day/atmos/tasmin/r1i1p1/v1.0/ /home/ubuntu/anomaly_folder/ --recursive --exclude "*" --include "*$1*" --exclude "*198*" --exclude "*197*" --exclude "*196*" --exclude "*195*" --exclude "*.json" --exclude "*.json*"
aws s3 cp  s3://nasanex/NEX-GDDP/BCSD/rcp45/day/atmos/tasmax/r1i1p1/v1.0/ /home/ubuntu/anomaly_folder/ --recursive --exclude "*" --include "*$1*" --exclude "*2016*" --exclude "*2017*" --exclude "*2018*" --exclude "*2019*" --exclude "*202*" --exclude "*203*" --exclude "*204*" --exclude "*205*" --exclude "*206*" --exclude "*207*" --exclude "*208*" --exclude "*209*" --exclude "*2100*" --exclude "*.json" --exclude "*.json*"
aws s3 cp  s3://nasanex/NEX-GDDP/BCSD/rcp45/day/atmos/tasmin/r1i1p1/v1.0/ /home/ubuntu/anomaly_folder/ --recursive --exclude "*" --include "*$1*" --exclude "*2016*" --exclude "*2017*" --exclude "*2018*" --exclude "*2019*" --exclude "*202*" --exclude "*203*" --exclude "*204*" --exclude "*205*" --exclude "*206*" --exclude "*207*" --exclude "*208*" --exclude "*209*" --exclude "*2100*" --exclude "*.json" --exclude "*.json*"

echo "Run the main script to compute temperature anomalies."

# Allow Anaconda and Python commands to be run in the shell script

#!/home/ubuntu/anaconda2/bin/python
export PATH=$PATH:/home/ubuntu/bin:/home/ubuntu/.local/bin:/home/ubuntu/anaconda2/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

echo $PATH

which python

# Allow the python codes to be run using the python filename.py command

sudo chmod 755 /home/ubuntu/PREPROCESS_full.py
sudo chmod 755 /home/ubuntu/ProjectCode.py

# Run the preprocessing code to convert NetCDF4 files into Zarr files

python /home/ubuntu/PREPROCESS_full.py

# Run the main processing code which implements Dask parallelism

python /home/ubuntu/ProjectCode.py

# Make a results directory and move the output files from ProjectCode.py into the new directory 

mkdir results
mv PC1.csv results/PC1_$1.csv
mv PC2.csv results/PC2_$1.csv
mv PC3.csv results/PC3_$1.csv
mv anomalies_dif.csv results/anomalies_dif_$1.csv
mv anomalies.csv results/anomalies_$1.csv
mv times.csv results/times_$1.csv
mv taylor_diagram.csv results/taylor_diagram_$1.csv

# Recursively upload all the files within the results folder to the group 7 S3 bucket

aws s3 cp /home/ubuntu/results s3://cs205project-files-group7 --recursive
