output "lb_arn" {
  description = "The ARN of the load balancer created."
  value       = aws_lb.alb.arn
}

output "lb_name" {
  description = "The name of the load balancer created."
  value       = aws_lb.alb.name
}

output "lb_dns_name" {
  description = "The dns_name of the load balancer created."
  value       = aws_lb.alb.dns_name
}

output "lb_web_acl_arn" {
  description = "The ARN of the web ACL of the load balancer created."
  value       = aws_wafv2_web_acl_association.wacl.web_acl_arn
}

output "web_acl_arn" {
  description = "The arn of the web ACL created."
  value       = aws_wafv2_web_acl.wacl.arn
}

output "web_acl_capacity" {
  description = "The capacity of the web ACL created."
  value       = aws_wafv2_web_acl.wacl.capacity
}

output "web_acl_name" {
  description = "The name of the web ACL created."
  value       = aws_wafv2_web_acl.wacl.name
}
