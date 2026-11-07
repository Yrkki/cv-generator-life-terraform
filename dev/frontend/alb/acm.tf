# Request the NEW Certificate in the ALB's Region
#################################################

# Request a new certificate in the ALB's region (using the default provider: aws)
resource "aws_acm_certificate" "alb_regional_cert" {
  # Use the default provider (var.region)

  # Set the primary domain based on the existing cert
  domain_name       = local.root_domain
  validation_method = "DNS"

  # Added to ensure the Key Algorithm matches the source certificate (RSA 2048)
  key_algorithm = local.key_algorithm

  # Use the manually defined local list for Subject Alternative Names.
  subject_alternative_names = local.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.naming.name}-alb-regional-cert"
  }
}

# DNS Validation (Step 3 from the plan)
##########################################
# Creates the necessary CNAME records in Route 53 for validation

resource "aws_route53_record" "cert_validation" {
  # Iterates over all domain validation options provided by ACM
  for_each = {
    for dvo in aws_acm_certificate.alb_regional_cert.domain_validation_options : dvo.domain_name => dvo
  }

  # The hosted zone ID must be available (e.g., via a variable or data source)
  zone_id = var.route53_hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = local.acm_validation_ttl
}

# Waits for the certificate to be fully issued by ACM before proceeding
resource "aws_acm_certificate_validation" "alb_cert_validation" {
  certificate_arn         = aws_acm_certificate.alb_regional_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
