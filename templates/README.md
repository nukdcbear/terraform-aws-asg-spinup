# Terraform AWS ASG Spinup

## Table of Contents

- [Terraform AWS ASG Spinup](#terraform-aws-asg-spinup)
  - [Table of Contents](#table-of-contents)
  - [About <a name = "about"></a>](#about)
  - [Requirements <a name = "requirements"></a>](#requirements)
  - [System Requirements <a name = "system-requirements"></a>](#system-requirements)
  - [Usage <a name = "usage"></a>](#usage)

## About <a name = "about"></a>

Example Terraform code to spinup an AWS auto scaling group of EC2 instances with a load balancer creating a Route53 record for the ALB.

This example is using a NGINX Ubuntu based AMI and will interact with Venafi DevOpsACCELERATE to generate a test cert and configure the ALB instance for https.

## Requirements <a name = "requirements"></a>

- HashiCorp [Terraform, >v0.12.0](https://www.terraform.io/downloads.html)
- [AWS Account](https://aws.amazon.com/console/)
- [Venafi DevOpsACCELERATE (cloud) account](https://ui.venafi.cloud/login)

## System Requirements <a name = "system-requirements"></a>

This can be executed on either a Windows or Linux system

Must set environment variables for AWS credentials; access key and secret key and Venafi credentials; api and zone.

AWS S3 bucket for backend state storage.

Ubuntu based AMI with NGINX installed

## Usage <a name = "usage"></a>

```bash
# Clone the respository
git clone git@github.com:nukdcbear/terraform-aws-asg-spinup.git

# cd in the directory
cd terraform-aws-asg-spinup

# Execute Terraform
terraform init -backend-config="<AWS S3 bucket>" -backend-config="key=<tfstate path/file>"
terraform plan -out=mytfplan
terraform apply mytfplan
```