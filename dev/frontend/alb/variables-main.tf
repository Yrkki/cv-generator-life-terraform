# Locals
#############################################
locals {
  default_account_alias = "jorich2018"
  vpc_cidr_prefix       = "172.64"

  http_port  = 80
  https_port = 443

  config = {
    description         = "Configuration data"
    vpc_cidr            = "${local.vpc_cidr_prefix}.0.0/16"
    public_subnet_cidrs = ["${local.vpc_cidr_prefix}.0.0/24", "${local.vpc_cidr_prefix}.20.0/24", "${local.vpc_cidr_prefix}.40.0/24"]
    role_arn            = "arn:aws:iam::${var.account_id[local.default_account_alias]}:role/FederatedAccess"
  }
}

# Variables
#############################################
variable "naming" {
  type        = map(string)
  description = "Naming"
  default = {
    name         = "cv-generator"
    short_name   = "cvgenerator"
    project_name = "CV Generator"
  }
}
variable "hosting" {
  type        = string
  description = "Hosting platform domain name"
  default     = "herokuapp.com"
}
variable "account_id" {
  type        = map(string)
  description = "Account ID"
  default = {
    marinov    = "801610064192"
    yrkki      = "864981721433"
    jorich     = "802807423235"
    jorich2018 = "956474664196"
  }
}
variable "region" {
  type        = string
  description = "Region"
  default     = "eu-west-1"
}
variable "azs" {
  type        = list(string)
  description = "Availability zones"
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}
variable "lb_access_logs_s3_bucket_name" {
  type        = string
  description = "Load balancer access logs S3 bucket name"
  default     = "elb-access-logs-marinov"
}

variable "app_runner_endpoint" {
  type        = string
  description = "App Runner endpoint"
  default     = "cvgenerator.c.marinov.link"
}

variable "cert_source_region" {
  type        = string
  description = "The region where the original certificate is located (us-east-1)."
  default     = "us-east-1"
}

variable "shared_cloudfront_endpoint" {
  type        = string
  description = "The domain name of the externally managed/shared CloudFront distribution used for maintenance/failover."
  default     = "d3v2pfjkkulyt1.cloudfront.net"
}

variable "alb_ssl_policy" {
  type        = string
  description = "The SSL policy for the HTTPS listener on the ALB. Use a modern policy like 'ELBSecurityPolicy-TLS13-1-0-2021-06'."
  default     = "ELBSecurityPolicy-TLS13-1-0-2021-06"
}
