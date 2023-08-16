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
variable "default_account_alias" {
  type        = string
  description = "Default account alias"
  default     = "jorich2018"
}
variable "account_id" {
  type        = map(string)
  description = "Account ID"
  default = {
    marinov    = "801610064192"
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
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "172.48.0.0/16"
}
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDR values"
  default     = ["172.48.0.0/24", "172.48.20.0/24", "172.48.40.0/24"]
}
variable "lb_access_logs_s3_bucket_name" {
  type        = string
  description = "Load balancer access logs S3 bucket name"
  default     = "elb-access-logs-marinov"
}

# Locals
#############################################
locals {
  config = {
    description = "Configuration data"
    # # Route53 _name = "${var.naming.short_name}.marinov.link"
    role_arn = "arn:aws:iam::${var.account_id[var.default_account_alias]}:role/FederatedAccess"
  }
}

# Provider
#############################################
provider "aws" {
  region = var.region

  assume_role {
    role_arn = local.config.role_arn
  }
}

# VPC
#############################################
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.naming.name}-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.naming.name}-${element(var.azs, count.index)}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.naming.name}-igw"
  }
}

resource "aws_route" "r" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_vpc.main.default_route_table_id
}

# Security groups
#############################################
resource "aws_security_group" "public" {
  name        = "${var.naming.name}-public-sg"
  description = "Public internet access"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.naming.name}-public-sg"
  }
}

resource "aws_security_group_rule" "public_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public_in_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public_in_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

# ELB
#############################################
resource "aws_lb" "alb" {
  name               = "${var.naming.name}-alb"
  internal           = false
  load_balancer_type = "application"

  drop_invalid_header_fields = true
  enable_deletion_protection = true
  access_logs {
    bucket  = var.lb_access_logs_s3_bucket_name
    enabled = true
  }

  subnets         = concat(aws_subnet.public_subnets[*].id)
  security_groups = [aws_security_group.public.id]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn

  protocol = "HTTP"
  port     = "80"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = 200
      message_body = "${var.naming.project_name} ellastic load ballancer working..."
    }
  }
}

resource "aws_lb_listener_rule" "cv-generator" {
  listener_arn = aws_lb_listener.listener.arn

  action {
    type = "redirect"
    redirect {
      host        = "${var.naming.name}-fe.${var.hosting}"
      path        = "/#{path}"
      query       = "#{query}"
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  condition {
    http_request_method { values = ["GET"] }
  }
}

resource "aws_lb_listener_rule" "cv-generator-eu" {
  listener_arn = aws_lb_listener.listener.arn

  action {
    type = "redirect"
    redirect {
      host        = "${var.naming.name}-fe-eu.${var.hosting}"
      path        = "/#{path}"
      query       = "#{query}"
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  condition {
    http_request_method { values = ["GET"] }
  }
}

# WAF
#############################################
resource "aws_wafv2_web_acl" "wacl" {
  # capacity = 10
  name        = "${var.naming.name}-wacl"
  description = "${var.naming.project_name} Web ACL."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.naming.name}-wacl-tf-metric-name"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "wacl" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.wacl.arn
}
