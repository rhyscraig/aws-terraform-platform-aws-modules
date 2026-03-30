output "zone_ids" {
  description = "Map of site key → Route53 hosted zone ID"
  value       = { for k, z in aws_route53_zone.sites : k => z.zone_id }
}

output "zone_arns" {
  description = "Map of site key → Route53 hosted zone ARN"
  value       = { for k, z in aws_route53_zone.sites : k => z.arn }
}

output "name_servers" {
  description = "Map of site key → list of Route53 nameservers"
  value       = { for k, z in aws_route53_zone.sites : k => z.name_servers }
}

output "cert_arns" {
  description = "Map of site key → validated ACM certificate ARN (us-east-1)"
  value       = { for k, v in aws_acm_certificate_validation.sites : k => v.certificate_arn }
}
