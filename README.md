# Project ecs-wl-ssl-gateway, ECS WhiteLabel SSL Gateway

## Infrastructure
The infrastructure is coded using Terrafrom. https://www.terraform.io/

### Infrastructure requeriments
  1. Existing an EC2 Autoscaling Group
  2. Existing an ECS Cluster
  3. Configured an ECS Cluster Cloudwatch metrics alarms
  4. Deployed an SNS-Lambda function to scale down safety
  5. Configured an Autoscaling lifecycle hook and Autoscaling notification to SNS topic

### Deployment instructions
  1. Make sure your AWS credentials/profile are correctly set in ~/.aws/credentials, and exported.
  2. Configure the backend state file:

      `terraform init`

  3. Switch to staging environment:

    `terraform env new stg`

    >**NOTE**: Use short, 3-char names for environments, due to AWS naming constraints.

  4. Edit the evironment variables, adapt them to you needs (key file, etc.)
     You can found one tfvars file for each environment.

      `nano (env-stg.tfvars | nano sbx-stg.tfvars | prd-stg.tfvars)`

  5. Review the execution Plan:

      `terraform plan -var-file=env-stg.tfvars`

  6. Deploy the infrastructure:

      `terraform apply -var-file=env-stg.tfvars`

  Once deployed, terraform state will be stored in an AWS S3 bucket, using server side encryption.

  >**NOTE**: Make sure to pull last changes before start working in any environment.

## Application ecs-wl-ssl-gateway

### Description
This application was designed to complain 3 aims:
  - Maintain the SSL certificates and keys isolated.
  - Decrease the complexity to adding new Whitelabels partners
  - Deacopling AWS LB Constraints from the Whitelabels Web project

### Components
The application is stored under the docker directory. It is a docker container based on alpine-nginx that acts as reverse proxy handling the SSL connections complexity (Offloading SSL)

It has two components:
  - Alpine-Nginx
  - ecs-wl-ssl-gateway.py

### Details about am-ssl-autoconf.py
This is a Python script to generate the Nginx ssl vhosts based on a yaml config file and download the certificates and keys from an protected S3 bucket as well.
