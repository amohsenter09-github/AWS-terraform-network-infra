variable "region" {
  description = "The region to deploy the VPC in eu-west-1"
  type        = string
  default     = "eu-west-1"
}

## These envs are mapped to workspaces names
variable "vpc_cidr_rang" {
  description = "The CIDR block for the VPC, define in each env variable file"
  type        = map
  default     = {}
}
variable "availability_zone" {
  description = "A map of availability zones to CIDR blocks, which will be set up as subnets."
  type        = list
  default     = []
}

variable "db_instance_type" {
  default = "db.r5.4xlarge"
}
