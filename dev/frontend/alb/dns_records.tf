/*
# Note: This is a conceptual Terraform file.
# Replace 'example_zone_id' and 'cloudfront_hosted_zone_id' with the 
# actual Zone ID and the correct Hosted Zone ID for CloudFront 
# in the region where the CloudFront distribution is deployed.

# 1. Define the CloudFront Distribution Domain Name
# This value is provided by the user: "d3v2pfjkkulyt1.cloudfront.net"
variable "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  default     = "d3v2pfjkkulyt1.cloudfront.net"
}

# The Hosted Zone ID for CloudFront (this is a constant value globally for CloudFront)
variable "cloudfront_hosted_zone_id" {
  description = "The canonical Hosted Zone ID for CloudFront."
  default     = "Z2FDTNDATAQYW2" # Standard CloudFront Zone ID
}

# 2. Define the Target DNS Zone ID (Replace with the actual hosted zone ID)
variable "dns_zone_id" {
  description = "The Hosted Zone ID for the 'cvgenerator.marinov.link' domain."
  # Placeholder for the actual DNS Zone ID
  default = "Z09148102PIA6CNULF3OA" 
}

# --- A Record Alias (IPv4) ---
# Creates an A record for 'maintenance.cvgenerator.marinov.link'
# that aliases to the CloudFront distribution.
resource "aws_route53_record" "maintenance_a" {
  # Change 'aws_route53_record' to the specific DNS provider resource if not AWS.
  zone_id = var.dns_zone_id
  name    = "maintenance.cvgenerator.marinov.link"
  type    = "A"
  
  # ALIAS target definition
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# --- AAAA Record Alias (IPv6) ---
# Creates an AAAA record for 'maintenance.cvgenerator.marinov.link'
# that aliases to the CloudFront distribution (essential for IPv6 support).
resource "aws_route53_record" "maintenance_aaaa" {
  # Change 'aws_route53_record' to the specific DNS provider resource if not AWS.
  zone_id = var.dns_zone_id
  name    = "maintenance.cvgenerator.marinov.link"
  type    = "AAAA"

  # ALIAS target definition
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
*/