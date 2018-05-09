## Intercomparison of Historical Temperature Anomalies in Climate Models

By Eimy Bonilla, Peter Sherman, and Matthew Stewart

## 1. Introduction
<p align="justify">
Global warming has been one of the hottest topics in environmental science for the past few decades. While many individuals and organizations have invested considerable time and resources into studying global warming, there are still some major discrepancies on the topic. One of the most profound of these discrepancies is the disagreement of estimates for global surface temperature anomalies between climate models and observations, which is shown in Figure 1. 


<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig1.png" width="600" alt="SERIAL"/>

<p align="center">
  <b>Figure 1</b> – Time series data (1960-2015) of surface temperature anomalies from the Coupled Model Intercomparison Project 5 (CMIP5) (Taylor et al., 2012) simulations and observations.

<p align="justify">
From Figure 1, it is clear that the models correlate well with observations from 1960 to 2000. However, from 2000 we start to see observational estimates plateau while the model estimates continue to increase. Although this deviation is well known, it is not well understood. The aim of this project is two-fold: (1) to compare temperature estimates from 21 CMIP5 models with observations from NASA GISS (GISSTEMP, 2018) and (2) to create a public framework that can be re-used by researchers to test their climate models for comparison. For the purposes of this class, we will focus more on the latter than the former because that is where the parallel implementation comes into play.

<p align="justify">
The CMIP5 data will be obtained from NASA NEX-GDDP, a dataset which consists of 21 models each of which has 66 years of daily minimum and maximum temperature estimates, spread over a global grid mesh with 0.25 degree spatial resolution. Following Lin and Huybers, 2016, the mean monthly temperature over the period 1950 to 1980 will be used to calculate temperature anomalies from 1990 to 2015. This data will then be compared on a cell-by-cell basis to the observation data. The observational data used in this study will be obtained from GISS, for land-surface temperature anomalies, and from NOAA ERSST V5, for sea-surface temperature anomalies. 

<p align="justify">
Due to the large combined size of these datasets (~2TB), performing calculations using a laptop is largely untenable in terms of data storage and computation time, and hence it is necessary to utilize a computing infrastructure that can handle large datasets and implement multiple forms of parallelism. Researchers at NCAR have previously developed a Python tool that implements mpi4py to analyze climate model data (Paul et al., 2016), However, the model is limited in that the user can request only one computation each time the tool is run. 

<p align="justify">
The goal of our project is to create a framework that allows the user to easily intercompare observation and historical model temperature data. We accomplished this developing an automated system which can be used to create and run multiple instances from the command line. To do this, the Simple System Manager (SSM) on Amazon Web Services (AWS) was used. The relevant software packages and data were stored on a public Amazon Machine Image (AMI), from which 20 instances were instantiated and run from a single shell script on a node. (Note: we could not perform the analysis on the 21 CMIP5 models due to the AWS limits, which limit us to 20 instances at once.) These instances would then follow their own shell script in which they downloaded specific climate model data from the NASA NEX-GDDP S3 bucket, converted these to more efficiently readable file types, and then performed statistical analysis on these using Python and Dask. This data was saved to a publicly available S3 bucket. The framework developed here can be easily run by downloading the public AMI and altering relevant parameters in the master code.

## 2. Methodology

<p align="justify">
The parallelization of our project was conducted in two phases. First we parallelized the temperature anomaly processing using Dask. We then parallelized the processing of different models through the use of AWS.

### 2.1 Dask parallelization

<p align="justify">
As Spark has difficulties handling NetCDF files, a state-of-the-art Python package that was released in early 2018, known as Dask, was used instead in order to manipulate the datasets. Dask contains its own OpenMP-style shared-memory parallelism, which was applied to the data to minimize computation time. This was coupled with another package, Xarray, which is a multidimensional implementation of Pandas developed for large datasets. Setting up a distributed cluster using Dask was abandoned due to time constraints and lack of knowledge of implementing this using Kubernetes and Helm – the most common way of implementing a distributed cluster on Dask. AWS was chosen for the infrastructure used for computation of the models, and interacted with the public dataset and instances via the AWS command line interface (CLI). Below (Figure 2), shows the summary of the software packages utilized in the computing framework.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig2.png" width="800" alt="SERIAL"/>
  
<p align="center">
  <b>Figure 2</b> - Summary of Software Packages

<p align="justify">
One of the major challenges that was encountered was reading the NetCDF files into memory. Initially, the program was run on a NetCDF file, which took approximately 5 minutes to load each file. These files are also extremely large and took up a huge amount of disk space. As it was not the goal of this project to deal with this I/O issue, the files were downloaded and then autonomously converted to Zarr files, a more efficient data storage format. Once the Zarr files had been setup, each of the file computations was completed in less than 10 seconds and data reading and writing was in the realm of milliseconds.

<p align="justify">
For the data analysis, we divided the Python code into six sections. The first loaded the observational data and used a linear regression to compute the slope (in ˚C months-1) for each latitude and longitude over the period 1990-2015. The second and third sections loaded the model data and computed the spatial monthly means and standard deviations, which were used to calculate the model slopes over the period 1990-2015 to be compared with the observations. Section five performed a principal component analysis (PCA) on the model anomalies from 1990-2015. Finally, section six computed the difference in slopes between the observations and models. The Python packages required to run this file are shown in Table 1 below.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Table1.png" width="600" alt="SERIAL"/>
  
<p align="center">
  <b>Table 1</b> – The essential packages that were installed for the Python code.


<p align="justify">
Sections one through four were parallelized using various Dask schedulers, as can be seen in the results section. For the Dask parallelization, we varied the number of workers and observed the speedup i.e. a strong scaling. Weak scaling was performed by lowering the spatial resolution of the temperature data and varying the number of workers accordingly to make the ratio of processors to problem size constant. It was deemed unnecessary to parallelize sections five and six because the serial versions completed quickly (~a few milliseconds). 

### 2.2 File parallelization through AWS

<p align="justify">
As important as the Dask parallelization is for speeding up the processing, the overall code can be parallelized further since each model analysis is independent of each other. This means that we can employ 20 AWS instances working independently of each other to perform the analysis on the 20 CMIP5 models. To do this, we created a t2.2xlarge instance, with all of the essential Python packages installed on it (see Table 1), and then saved the configuration as an AMI. This AMI could then be instantiated multiple times and the automation of each controlled by a pre-installed SSM agent. This was necessary since each model run takes several hours, and by creating an automated system which runs 20 instances in parallel, we would be able to reduce the time for all models to a couple of hours. Each instance was backed with Elastic Block Storage (EBS) and given 200GB of storage space - a sufficient amount to download and store the climate data, the generated zarr files, and all other software packages.

<p align="justify">
The AMI is essentially a template that allows us to create new instances that have the same software and files as the imaged instance. The files downloaded on the image are **ProjectCode_Master.sh** (the master script), **ProjectCode.sh** (the script run on the 20 copied instances), **ProjectCode.py** (the parallelized Dask code), **PREPROCESS_full.py** (preprocessing of NetCDF files into Zarr filetype) and a folder called **observations** (contains the observational data). The user simply needs a root instance where they type the command <i>bash ProjectCode_Master.sh</i> and the rest of the process is automated. 

<p align="justify">
The first step was to create 20 copied instances and have them download different models. To send commands between instances, we needed to configure the AWS Identity and Access Management (IAM) policy, [detailed here](https://protechgurus.com/working-amazon-ec2-run-command-ssm-agent/). The IAM policy provided full read/write access to S3 and full access to SSM; this set of policies was added to each instance after instantiation. Once the models finished downloading on each instance, the NetCDF files were converted to zarr folders and then processed in the Python code detailed above. Results from the code for each model were stored on a public S3 bucket, available [from this link](https://s3.console.aws.amazon.com/s3/buckets/cs205project-files-group7/?region=us-east-1&tab=overview). These results can be replicated by accessing the public image through US West (Oregon) using the AMI ID **ami-f1334289**. The data flow and infrastructure setup is shown graphically in Figure 3.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig3.png" width="700" alt="SERIAL"/>
  
<p align="center">
  <b>Figure 3</b> – Illustration of the dataflow and infrastructure setup used in this project.

## 3. Results

### 3.1 Dask parallelization

<p align="justify">
As noted earlier, we changed the files from NetCDF to Zarr to reduce the IOPS in reading and writing data. The speedup from this conversion is negligible on a local machine (from microseconds to milliseconds), but significant on an AWS instance, as seen on Figure 4.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig4.png" width="600" alt="SERIAL"/>
  
<p align="center">
  <b>Figure 4</b> – Time to load NetCDF and Zarr files on a local machine (3.1 GHz Intel Core i5 MacBook Pro) and t2.2xlarge AWS instance. Note the logarithmic scale for the y-axis.

<p align="justify">
There is a significant reduction in loading time when using Zarr files instead of NetCDF on AWS instances. Zarr files are also 10x smaller in size than NetCDF files, and thus can be loaded into the memory of smaller instances and made them more computationally tractable for smaller instance sizes.

<p align="justify">
After converting the NetCDFs to Zarrs, we performed strong and weak scalings based on our Python code. Results are displayed in Figures 5(a) and (b).

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig5.png" width="900" alt="SERIAL"/>

<p align="center">
  <b>Figure 5</b> – Speedup plots of the Dask parallelized sections for (a) strong and (b) weak scalings.

<p align="justify">
We see that there is little discrepancy between threaded and multiprocessing schedulers on Dask from Figure 5(a). The speedup peaks between 4 and 8 workers, and plateaus after. While sections 1 through 4 are embarrassingly parallel, we do not see a linear speedup, likely because Dask has only recently been developed and still has issues to address (Lu, 2017), i.e. Dask cannot currently parallelize ‘sortby’ functions that are essential for our monthly mean calculations. We also see from Figure 5(b) that there is speedup as we increase the problem size. For weak scaling, linear scaling is achieved if the run time stays constant while the workload is increased in direct proportion to the number of processors. In this project, this was not observed. The slow down observed for smaller numbers of workers is likely due to additional overheads that are present when reindexing the size of the data. Reindexing data to lower resolutions requires more computation per iteration and thus significantly reduces performance when only using one or two worker nodes. Reindexing of this data to determine weak scaling did not provide useful results and was merely performed to see how data would scale for increasingly large datasets. Plateauing occurs at higher numbers of workers due to limitations by sequential portions of the code, present in the ‘sortby’ functions within Dask.

### 3.2 File parallelization through AWS

<p align="justify">
Due to large selection of instances available on AWS, it is important to determine the best instance to utilize for a specific task. For an amateur AWS user, selecting the correct instance is not a trivial task. To make it easier for future users to determine which instance gives the best performance given certain constraints, the cheapest instance types with sufficient memory were run and their relative cost and performance characteristics were compared. Other types of instances could have been examined, such as compute-optimized instances (e.g. i-type instances), memory-optimized instances (e.g. d-type instances) or even accelerator-based instances (e.g. g-type instances). However, due to the prohibitively high costs of these instances, as well as time constraints, only 4 instances were examined: two t-type and two m-type instances (Table 2). These are the most prevalent instance types used for general computing and cluster computing when running Spark/Mapreduce, and hence these were deemed the most relevant to compare.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Table2.png" width="600" alt="SERIAL"/>

<p align="center">
  <b>Table 2</b> – Cost-performance analysis of 20 instances processing the model data.

<p align="justify">
The optimal choice of instance depends on the most essential criteria for the user. For a researcher on a budget constraint, the t2.large instance is clearly the best choice. Contrastingly, if minimal computation time is required then the user should opt for 21 m4.4xlarge. Interestingly, it was determined that running the models on m4.2xlarge instances was both faster and cheaper than on t2.2xlarge instances. However, it should be noted that service limit increases are required for all of these in order to run more than 20 concurrent t-instances or more than 5 m-instances. Instances smaller than t2.large were unable to be used due to insufficient memory requirements.

### 3.3 Example outputs

<p align="justify">
Here we include results derived from the Python script. Figure 6 shows the difference in anomaly slopes (observations – models) for two example cases. Figure 6(a) shows the model that deviates the least from the observations and Figure 6(b) shows the model that had the greatest deviations. This difference is particularly notable in the Arctic. We see that the observations and CEM1-BCG largely agree, while the observations and immcm4 do not.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig6.png" width="700" alt="SERIAL"/>
  
<p align="center">
  <b>Figure 6 </b>– Difference in anomaly slopes between observations and (a) CEM1-BCG and (b) inmcm4. 

<p align="justify">
Figure 7 shows the PCA on the observations and two models. The model examples shown on this figure are the ones that seemed the most and least similar to the patterns found by the first three principal components (PCs)  on the observation data. The PCs for the observations are on figure 7 (a), the most similar by model are on figure 7(b), and the least similar on figure 7 (c).  

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig7.png" width="800" alt="SERIAL"/>
  
<p align="center">
  <b>Figure 7</b> – EOF plots for the first three PCAs over the period 1990-2015 for (a) the observations, (b) MIROC-ESM-CHEM and (c) CSIRO-Mk3-6-0.

<p align="justify">
It should be noted that while these results are interesting, they were not the main focus of this project. For simplicity, we have largely replicated the methodology shown in Lin and Huybers, 2016. More rigorous analysis could easily be added to the Python script to provide more rigorous intercomparison between observations and models, and – if necessary – be parallelized with Dask and other forms of parallelism. 

## 4. Discussion and Conclusion

<p align="justify">
Here, we have developed an AWS framework that can be implemented to compare climate models with both observations and themselves. This framework parallelizes both the processing of models through the use of multiple instances managed by AWS SSM agents, as well as the analysis within each instance using Dask. We found that the threading and multiprocessing schedulers have comparable performance within the Python code, i.e. the difference between schedulers is not deemed to be significant. However, Dask is still in the nascent phases of development and still contains multithreading and multiprocessing inefficiencies, which resulted in sub-optimal speedup compared to the expected linear scaling. A cost-analysis was performed on different instances and found that the optimal choice of instance varies depending on the specific requirements of the user. We hope that this framework can be expanded further and easily utilized by climate researchers.

<p align="justify">
There are, however, areas we would like to improve in the future. As stated earlier, we would like to include more calculations for each model to allow for even greater ease of comparison with observations. Further implementations of parallelism through the use of distributed-memory parallelism or accelerator-based parallelism on Python, using packages such as mpi4py and PyAcc would also be beneficial. Optimization of Dask scheduler-based parallelism once it has been developed into a more robust framework is also desirable and should be pursued. These packages were deemed too time consuming and unnecessary due to the dominant overhead of the data download and preprocessing tasks and thus were not utilized. It would be helpful to connect the framework with Jupyter Notebook so that the user could readily visualize data after the processing is complete. As a final step that could be most beneficial to the user, we should implement more instance types to provide a more comprehensive cost/performance analysis.

## 5. Exascaling

<p align="justify">
It is expected in the coming years and decades that environmental datasets involving satellite data will approach the petabyte- and exabyte-scale. This would come from increasing improvements in data resolution from advanced satellite technology, which could increase granularity of the data to several metres of Earth. Such datasets are far beyond the computational capabilities of a single PC, and even beyond capabilities of the framework developed in this paper. As such, scaling to datasets of this size would require alterations to the computing framework to make them computationally feasible given today’s available resources.

<p align="justify">
Rough estimates based on data from this paper reveal that sequential execution time for computation of petabyte- and exabyte- scale datasets would require 2 years and 1500 years respectively. This is clearly not realistic, and requires extensive parallelism to make this computationally tractable. One method proposed to make this more tractable is to continue to use AWS SSM to separate different models, which can then be computed in their own distributed-cluster, such as the StarCluster, a distributed-cluster based on Mpi4py developed by MIT. Within this cluster, anywhere from two to a hundred nodes could be used to aid in this computation, with no communication overhead since this is an embarrassingly parallel problem. Additional parallelism could be implemented within each cluster by using instances which are able to utilize accelerated computing, such as g-type instances running PyAcc. Such an implementation is shown in Figure 8.

<p align="center">
  <img src="https://github.com/ebonil01/cs205project/blob/master/Fig8.png" width="700" alt="SERIAL"/>
  
<p align="center">
  <b>Figure 8</b> - Software implementation for exascale climate data computation.

<p align="justify">
Utilizing this infrastructure could reduce execution time of a 1PB dataset to 3 days on 10-node  clusters, and around 8 hours using 100-node clusters. For a 1EB dataset, using 100-node clusters would require 300 days of computation. These execution times are not ideal, but turn this problem from being computationally impossible to becoming far more tractable - no Harvard student in the future will have to wait a thousand years to examine their climate datasets.

## 6. References

AWS System Manager User Guide (2018). Accessed 2018-04-15 at https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-ug.pdf

Dask Documentation Guide - Release 0.17.4 (2018).

GISTEMP Team (2018). GISS Surface Temperature Analysis (GISTEMP). NASA Goddard Institute for Space Studies. Dataset accessed 2018-04-15 at https://data.giss.nasa.gov/gistemp/.

Lin, M. & Huybers, P. (2016). Revisiting whether recent surface temperature trends agree with the CMIP5 ensemble. J. Clim. 29, 8673–8687.

Lu, F.  (2017) Big data scalability for high throughput processing and analysis of vehicle engineering data. Masters of Science Thesis. KTH Royal Institute of Technology School of Information and Communication Technology. Accessed 2018-05-08.

Paul, K., Mickelson, S., Dennis, J.M. (2016). A new parallel python tool for the standardization of earth system model data. 2953-2959. 10.1109/BigData.2016.7840946.

Taylor, K.E., Stouffer, R.J., Meehl, G.A. (2012). An Overview of CMIP5 and the experiment design.” Bull. Amer. Meteor. Soc., 93, 485-498, doi:10.1175/BAMS-D-11-00094.1.

Zhuang, J., 2018. Dask Examples. Accessed 2018-04-15 at http://cloud-gc.readthedocs.io/en/latest/chapter04_developer-guide/install-basic.html

</p>

