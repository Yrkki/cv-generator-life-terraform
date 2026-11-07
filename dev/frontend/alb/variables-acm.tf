# Locals
#############################################
locals {
  # Set TTL for consistency with existing records
  acm_validation_ttl = 300

  # Primary domain
  root_domain = "marinov.link"

  # Various domains
  domains = {
    marinov-link             = local.root_domain
    wildcard-eu-marinov-link = "*.eu.${local.root_domain}"
    wildcard-marinov-link    = "*.${local.root_domain}"
    wildcard-us-marinov-link = "*.us.${local.root_domain}"
    # # Route53 _name = "${var.naming.short_name}.${local.root_domain}"
  }

  # Manually define the list of all domains required for the new regional certificate.
  # This list is used to bypass the failing 'subject_alternative_names' attribute lookup.
  # It includes the primary domain name ("marinov.link") and any other names (e.g., "*.marinov.link").
  subject_alternative_names = [
    local.domains.wildcard-eu-marinov-link,
    local.domains.wildcard-marinov-link,
    local.domains.wildcard-us-marinov-link,
  ]

  # Added to ensure the Key Algorithm matches the source certificate (RSA 2048)
  key_algorithm = "RSA_2048"
}

# Variables
#############################################
variable "certificate_arn" {
  type        = string
  description = "The ACM Certificate ARN for the domain (must be in the same region as the ALB)."
  default     = "arn:aws:acm:us-east-1:802807423235:certificate/7a44c425-918d-47bb-9424-d6b5d2d7cb0a"
}

variable "route53_hosted_zone_id" {
  type        = string
  description = "The Route 53 Hosted Zone ID."
  default     = "Z09148102PIA6CNULF3OA"
}
