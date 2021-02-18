variable "aws_region" {
  type = string
  default = "eu-west-1"
}

variable "terraform_state_bucket" {
  description = "Name of S3 bucket for terraform state"
  type        = string
  default     = "vpc-environments-tfstate"
}

variable "terraform_state_dynamodb_name" {
  description = "Name of dynamodb name for storing terraform lock"
  type        = string
  default     = "vpc-environments-tflock"
}


variable "common_tags" {
  type = map(string)
  default = {
  Owner        = "amohsen"
  Service      = "The base VPC infra-structure"
  Product      = "Bose"
  Comment      = "ED-8102"
  Compliance   = "true"
  Environment  = "non-prod"
  }
}