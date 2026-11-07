# Locals
#############################################
locals {
  # The domain we are configuring the Failover for (Rule 3/Catch-All)
  app_runner_domain = "cvgenerator.c.marinov.link" 

  # The fixed Hosted Zone ID for ALL CloudFront distributions (Global constant)
  cloudfront_hosted_zone_id = "Z2FDTNDATAQYW2"
  
  # The external, shared CloudFront distribution endpoint.
  # THIS VALUE MUST BE UPDATED in variables-main.tf if the shared distribution is deleted and recreated.
  shared_cloudfront_endpoint = var.shared_cloudfront_endpoint 
}

# 1. Route 53 Health Check for the ALB
##########################################
# This health check monitors the specific CloudWatch Alarm.
# If the alarm state is "ALARM" (meaning 0 healthy targets), 
# this Route 53 check will report "unhealthy".
resource "aws_route53_health_check" "alb_failover_check" {
  # Type must be CLOUDWATCH_METRICS to monitor an alarm
  type = "CLOUDWATCH_METRICS"

  # CORRECT SYNTAX: Use cloudwatch_alarm_name and its region
  cloudwatch_alarm_name   = aws_cloudwatch_metric_alarm.alb_unhealthy_alarm.alarm_name
  cloudwatch_alarm_region = var.region
  
  # Set failure criteria
  insufficient_data_health_status = "Unhealthy"

  tags = {
    Name = "${var.naming.name}-alb-failover-check"
  }
}

# 2. Route 53 Primary (ALB) Record
##########################################
# This record is the primary target. It is associated with the health check.
resource "aws_route53_record" "app_runner_primary" {
  zone_id = var.route53_hosted_zone_id
  name    = local.app_runner_domain
  type    = "A"

  # Routing policy to use: PRIMARY
  failover_routing_policy {
    type = "PRIMARY"
  }

  # Alias target points to the new ALB (NOTE: aws_lb.main is assumed from main.tf)
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true # Mandatory for Failover Policy
  }

  # Associate with the health check created above
  health_check_id = aws_route53_health_check.alb_failover_check.id
}

# 3. Route 53 Secondary (Maintenance) Record
############################################
# This record is the secondary (failover) target.
resource "aws_route53_record" "maintenance_secondary" {
  zone_id = var.route53_hosted_zone_id
  name    = local.app_runner_domain
  type    = "A"
  
  # Routing policy to use: SECONDARY
  failover_routing_policy {
    type = "SECONDARY"
  }

  # Alias target points to the CloudFront distribution
  alias {
    # Reference the external CloudFront domain defined in locals
    name                   = local.shared_cloudfront_endpoint 
    # We now use the fixed CloudFront Hosted Zone ID
    zone_id                = local.cloudfront_hosted_zone_id
    evaluate_target_health = false # Not necessary for static content
  }

  # Note: The Secondary record does NOT need a health_check_id.
  
  /* IMPORTANT NOTE ON CONFLICTED PATH:
  Since this CloudFront distribution (d3v2pfjkkulyt1.cloudfront.net) is shared 
  and its Default Root Object cannot be changed, we must rely on CloudFront's 
  Custom Error Responses to show the maintenance page.

  The request from Route 53 will hit the distribution's root (/).

  Action required in CloudFront configuration (outside of this file):
  1. Ensure the maintenance page (e.g., "maintenance-mode.html") exists in the 
     S3 bucket behind this CloudFront distribution.
  2. Configure a CloudFront Custom Error Response for HTTP status 403 (Forbidden) 
     and/or 404 (Not Found) to return the path to the maintenance page (e.g., 
     "/maintenance-mode.html") with a 200 (OK) response code. 
     
  This configuration forces the maintenance page to display on failover 
  without changing the distribution's Default Root Object.
  */
}

# Data source for CloudFront distribution is REMOVED as its HZ ID is hardcoded.