variable "env_name" {
  description = "Environment name to be used to uniquely identify the domo spinup"
  default     = "domo-dev"
}

# ----

variable "aws_vpc_id" {
  default = "vpc-0e2a0b0d235345dd2"
}

variable "alb_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for Application Load Balancer (ALB)"
  default     = [
    "subnet-06d2f1d8a5a619fab",
    "subnet-00df16e9e366feed0",
    "subnet-01ad93c53d1c4f23c"
  ]
}

variable "domo_ingress_cidr_blocks" {
  type    = list(string)
  default = ["65.189.75.0/24"]
}

variable "ec2_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for EC2 instance - preferably private subnets"
  default     = [
    "subnet-06d2f1d8a5a619fab",
    "subnet-00df16e9e366feed0",
    "subnet-01ad93c53d1c4f23c"
  ]
}

variable "key_pair_name" {
  description = "SSH key pair"
  default     = "dcb-ec2keypair-pem"
}

variable "route53_hosted_zone_name" {
  type        = string
  description = "Route53 Hosted Zone where domo machines will reside"
  default     = "davidcbarringer.com"
}

variable "ingress_cidr_alb_allow" {
  type        = list(string)
  description = "List of CIDR ranges to allow web traffic ingress to Domo Application Load Balancer (ALB)"
  default     = ["0.0.0.0/0"]
}

variable "owner_team" {
  description = "Name of team owning resources"
  default     = "DomoVenafiTeam"
}