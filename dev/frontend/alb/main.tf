provider "aws" {
  region = "eu-west-1"
}

locals {
  alb_name = "cv-generator"
}

resource "aws_lb" "alb" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"

  # vpc_id             = "vpc-0e29045db07590c8a"
  subnets            = ["subnet-0494e737df7af5484", "subnet-0b33c43f036ae58c8"]
  security_groups    = ["sg-0bbd845a7c8739d08"]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn

  protocol          = "HTTP"
  port              = "80"

  default_action {
    type         = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = 200
      message_body = "CV Generator ellastic load ballancer working..."
    }
  }
}

resource "aws_lb_listener_rule" "cv-generator" {
  listener_arn = aws_lb_listener.listener.arn

  action {
    type = "redirect"
    redirect {
      host        = "cv-generator-fe.herokuapp.com"
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
      host        = "cv-generator-fe-eu.herokuapp.com"
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

resource "aws_wafv2_web_acl" "wacl" {
  # capacity = 10
  name        = "cv-generator-wacl"
  description = "CV Generator Web ACL."
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
    metric_name                = "cv-generator-wacl-tf-metric-name"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "wacl" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn   = aws_wafv2_web_acl.wacl.arn
}
