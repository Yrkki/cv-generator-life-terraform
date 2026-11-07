# This file includes the required Networking, Load Balancer, 
# Target Group, Listeners, and the CloudWatch Alarm for Failover.

# -----------------------------------------------------------------------------
# 1. NETWORKING (VPC, Subnets, Gateway)
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = local.config.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.naming.name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.naming.name}-igw"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(local.config.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.config.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index] # Using the defined AZs
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.naming.name}-pub-${var.azs[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.naming.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# 2. SECURITY GROUP (ALB Access)
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb_sg" {
  # Renaming from 'public' to 'alb_sg' to be more descriptive and avoid conflicts
  name        = "${var.naming.name}-alb-sg"
  description = "Allow inbound traffic on HTTP/HTTPS for ALB"
  vpc_id      = aws_vpc.main.id

  # Ingress for HTTP (Port 80)
  ingress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress for HTTPS (Port 443)
  ingress {
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress (All Outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.naming.name}-alb-sg"
  }
}


# -----------------------------------------------------------------------------
# 3. APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------

# Application Load Balancer (aws_lb.main)
resource "aws_lb" "main" {
  name               = "${var.naming.name}-alb"
  internal           = false
  load_balancer_type = "application"
  
  drop_invalid_header_fields = true
  enable_deletion_protection = false

  # Using the newly defined security group
  security_groups    = [aws_security_group.alb_sg.id] 
  
  # Link to the list of public subnets
  subnets            = aws_subnet.public_subnets[*].id
  
  access_logs {
    bucket  = var.lb_access_logs_s3_bucket_name
    enabled = true
  }

  tags = {
    Name = "${var.naming.name}-alb"
  }
}

# -----------------------------------------------------------------------------
# 4. TARGET GROUP
# -----------------------------------------------------------------------------

# Target group for App Runner endpoint
resource "aws_lb_target_group" "main" {
  name_prefix = "${var.naming.short_name}-tg"
  port        = local.https_port # App Runner is HTTPS, so traffic from ALB to App Runner is HTTPS
  protocol    = "HTTPS"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # App Runner targets are IP-based

  # Health Check Configuration (60s interval, 2 unhealthy threshold)
  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTPS"
    interval            = 60 # 60 seconds (as requested)
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2 # 2 failures means unhealthy (120 seconds detection time)
    matcher             = "200"
  }
  
  tags = {
    Name = "${var.naming.name}-tg"
  }
}

# Target Group Attributes MUST be set using a separate resource (aws_lb_target_group_attribute)
# This resource manages the specific attribute for the target group.
resource "aws_lb_target_group_attribute" "main_attributes" {
  target_group_arn = aws_lb_target_group.main.arn
  key              = "load_balancing.target_group.lambda.multi_value_headers.enabled"
  value            = "false"
}


# Attach the App Runner endpoint to the Target Group (The actual target is the App Runner service)
# This assumes the App Runner endpoint resolves to a known, stable IP or CNAME you can use. 
# For external services like App Runner, you often need to resolve the CNAME to IP addresses 
# and manage updates, but for simplicity here we assume a stable IP can be determined or 
# that an AWS Service Link will be used (which is more complex). We'll stick to IP for now.

# NOTE: App Runner CNAME must be manually resolved to IP addresses 
# and added as static targets in a real deployment. 
# For Terraform validation, we will skip the registration step as the IP is dynamic.
# In a real setup, you would use a Lambda/ECS task to constantly update this TG with 
# the resolved IP of the App Runner CNAME.

# -----------------------------------------------------------------------------
# 5. LISTENERS 
# -----------------------------------------------------------------------------

# Listener 1: HTTP (80) Listener to redirect to HTTPS (443)
# Renamed from 'http_redirect' to 'http_listener'
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener 2: HTTPS (443) Listener
# Renamed from 'https' to 'https_listener'
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = local.https_port
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.alb_cert_validation.certificate_arn # From acm.tf
  # Policy now uses the variable for easy updates
  ssl_policy        = var.alb_ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}


# -----------------------------------------------------------------------------
# 6. LISTENER RULES
# -----------------------------------------------------------------------------

# Rule 1 & 2 are now EXTERNAL REDIRECTS (301) for legacy Herokuapp domains to the canonical marinov.link domain.
# Rule 3 remains a FORWARD for the primary application domain.

# Rule 1: Legacy Host header for the primary app domain (e.g., cv-generator.herokuapp.com)
resource "aws_lb_listener_rule" "cv_generator_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 10 # Higher priority than other specific rules

  action {
    type = "redirect"
    redirect {
      # Redirect to the canonical domain name
      host        = "${var.naming.name}.marinov.link" 
      path        = "/#{path}"  # Preserve path
      query       = "/#{query}" # Preserve query
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["${var.naming.name}.${var.hosting}"] # e.g., cv-generator.herokuapp.com
    }
  }
}

# Rule 2: Legacy Host header for the European specific domain (e.g., cv-generator-eu.herokuapp.com)
resource "aws_lb_listener_rule" "cv_generator_eu_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 20

  action {
    type = "redirect"
    redirect {
      # Redirect to the canonical domain name
      host        = "${var.naming.name}.marinov.link"
      path        = "/#{path}"
      query       = "/#{query}"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["${var.naming.name}-eu.${var.hosting}"] # e.g., cv-generator-eu.herokuapp.com
    }
  }
}

# Rule 3: Host header for the Front-End Catch-All (cvgenerator.c.marinov.link) (Primary active domain - Must FORWARD)
resource "aws_lb_listener_rule" "cv_generator_fe_c_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = ["cvgenerator.c.marinov.link"] 
    }
  }
}


# -----------------------------------------------------------------------------
# 7. WAF WEB ACL AND ASSOCIATION
# -----------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "wacl" {
  # capacity = 10 # Capacity is calculated automatically by AWS
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
  
  tags = {
    Name = "${var.naming.name}-wacl"
  }
}

resource "aws_wafv2_web_acl_association" "wacl" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.wacl.arn # Reference the newly created WAF ACL
}


# -----------------------------------------------------------------------------
# 8. CLOUDWATCH METRIC ALARM (REQUIRED FOR ROUTE 53 FAILOVER)
# -----------------------------------------------------------------------------

# Alarm that fires if the Target Group has ZERO healthy hosts.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_alarm" {
  alarm_name          = "${var.naming.name}-alb-unhealthy-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60" # Check every 60 seconds
  statistic           = "Minimum"
  threshold           = "1" # Alarm fires if HealthyHostCount drops below 1

  dimensions = {
    TargetGroup = aws_lb_target_group.main.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  # Treat insufficient data (e.g., no traffic) as unhealthy
  insufficient_data_actions = ["ALARM"]
}
