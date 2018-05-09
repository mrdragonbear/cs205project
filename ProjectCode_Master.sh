#!/bin/bash

# Declare arrays for the instance id's and the model names to be used later

declare -a array=('inmcm4'  'bcc-csm1-1' 'NorESM1-M' 'IPSL-CM5A-LR' 'MPI-ESM-MR' 'MPI-ESM-LR' 'MIROC5' 'MIROC-ESM' 'MIROC-ESM-CHEM' 'IPSL-CM5A-MR' 'CCSM4' 'BNU-ESM' 'ACCESS1-0' 'GFDL-ESM2G' 'GFDL-CM3' 'CanESM2' 'CSIRO-Mk3-6-0' 'CNRM-CM5' 'CESM1-BGC' 'MRI-CGCM3' 'GFDL-ESM2M')
declare -a instances=()
declare -a instance_id=()

# Create 20 (or other number of) instances in a given region, subnet, and with a given security group, instance type, and AMI

counter1=1
while [ $counter1 != 21 ]
do
	instance_id=( ${instance_id[@]} $(aws ec2 run-instances --region us-west-2 --key cs205-HWB --instance-type m4.4xlarge --subnet-id subnet-2662aa5f --security-group-ids sg-2eddfb50 --count 1 --image-id ami-f1334289 --output text --query 'Instances[*].InstanceId') )
	instances=( ${instances[@]} '$instance_id' )
	echo ${array[$counter1-1]}
	echo ${instance_id[@]}
	((counter1++))
done

# Wait for the instances to initialize before proceeding

sleep 60

# Assign a policy role to each of the instances to allow access to reading and writing S3 buckets and running SSM commands

counter2=1
while [ $counter2 != 21 ]
do
	aws ec2 associate-iam-instance-profile --instance-id "${instance_id[$counter2 - 1]}" --iam-instance-profile Name="CS205"
	echo ${instance_id[$counter2-1]}
	((counter2++))
done

# Wait for the security policies to be enabled and for the instances to finish initializing before proceeding

sleep 360

# Send SSM commands to each instance to run ProjectCode.sh shell script with a different model as the argument for each node

aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[0]}" --parameters '{"commands":["bash ProjectCode.sh inmcm4"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[1]}" --parameters '{"commands":["bash ProjectCode.sh bcc-csm1-1"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[2]}" --parameters '{"commands":["bash ProjectCode.sh NorESM1-M"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[3]}" --parameters '{"commands":["bash ProjectCode.sh IPSL-CM5A-LR"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[4]}" --parameters '{"commands":["bash ProjectCode.sh MPI-ESM-MR"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[5]}" --parameters '{"commands":["bash ProjectCode.sh MPI-ESM-LR"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[6]}" --parameters '{"commands":["bash ProjectCode.sh MIROC5"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[7]}" --parameters '{"commands":["bash ProjectCode.sh MIROC-ESM"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[8]}" --parameters '{"commands":["bash ProjectCode.sh MIROC-ESM-CHEM"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[9]}" --parameters '{"commands":["bash ProjectCode.sh IPSL-CM5A-MR"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[10]}" --parameters '{"commands":["bash ProjectCode.sh CCSM4"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[11]}" --parameters '{"commands":["bash ProjectCode.sh BNU-ESM"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[12]}" --parameters '{"commands":["bash ProjectCode.sh ACCESS1-0"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[13]}" --parameters '{"commands":["bash ProjectCode.sh GFDL-ESM2G"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[14]}" --parameters '{"commands":["bash ProjectCode.sh GFDL-CM3"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[15]}" --parameters '{"commands":["bash ProjectCode.sh CanESM2"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[16]}" --parameters '{"commands":["bash ProjectCode.sh CSIRO-Mk3-6-0"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[17]}" --parameters '{"commands":["bash ProjectCode.sh CNRM-CM5"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[18]}" --parameters '{"commands":["bash ProjectCode.sh CESM1-BGC"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[19]}" --parameters '{"commands":["bash ProjectCode.sh MRI-CGCM3"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "${instance_id[20]}" --parameters '{"commands":["bash ProjectCode.sh GFDL-ESM2M"],"workingDirectory":["/home/ubuntu/"],"executionTimeout":["30000"]}' --timeout-seconds 10000 --region us-west-2 --output-s3-bucket-name "cs205project-files-group7"

