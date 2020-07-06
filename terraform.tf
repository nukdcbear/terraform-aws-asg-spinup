terraform {
  required_version = "> 0.12.0"
  required_providers {
    aws = "~> 2.62"
  }
  backend "s3" {
    # bucket - to be passed on init
    # key    - to be passed on init
    region  = "us-east-2"
    encrypt = true
  }
}

provider "aws" {
  region  = "us-east-2"
}

provider "venafi" {
  version = "= 0.9.2"
}

provider "local" {
  version = "~> 1.4"
}
