# module: dns-zone
#
# DNS + TLS certificate management — for_each over var.sites.
#
# For each site this module:
#   1. Creates a Route53 hosted zone
#   2. Optionally updates the NS records at the Route53 Registrar automatically
#   3. Issues an ACM certificate in us-east-1 (CloudFront requirement)
#   4. Writes DNS CNAME validation records and waits for issuance
#
# NOTE: ALIAS records (apex → CloudFront) are intentionally NOT in this module.
# They depend on the CloudFront distribution domain which comes from the consumer.
# Keeping ALIAS records in the calling environment breaks the circular dependency.

# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  # Flatten: one validation CNAME per (site × domain) combination.
  cert_validation_records = merge([
    for site_key, site in var.sites : {
      for dvo in aws_acm_certificate.sites[site_key].domain_validation_options :
      "${site_key}__${dvo.domain_name}" => {
        site_key = site_key
        name     = dvo.resource_record_name
        type     = dvo.resource_record_type
        record   = dvo.resource_record_value
      }
    }
  ]...)
}

# ── 1. Route53 hosted zones ────────────────────────────────────────────────────

resource "aws_route53_zone" "sites" {
  for_each = var.sites

  name    = each.value.domain
  comment = "${each.key} — managed by Terraform"
}

# ── 2. Route53 Registrar NS auto-update ───────────────────────────────────────

resource "aws_route53domains_registered_domain" "sites" {
  for_each = { for k, v in var.sites : k => v if v.manage_registrar_ns }

  domain_name = each.value.domain

  dynamic "name_server" {
    for_each = aws_route53_zone.sites[each.key].name_servers
    content {
      name = name_server.value
    }
  }
}

# ── 3. ACM certificates (us-east-1 — CloudFront requirement) ──────────────────

resource "aws_acm_certificate" "sites" {
  for_each = var.sites

  provider = aws.us_east_1

  domain_name               = each.value.domain
  subject_alternative_names = each.value.aliases
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ── 4. DNS CNAME validation records ───────────────────────────────────────────

resource "aws_route53_record" "cert_validation" {
  for_each = local.cert_validation_records

  zone_id         = aws_route53_zone.sites[each.value.site_key].zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# ── 5. Certificate validation waiter ──────────────────────────────────────────

resource "aws_acm_certificate_validation" "sites" {
  for_each = var.sites

  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.sites[each.key].arn

  validation_record_fqdns = [
    for k, r in aws_route53_record.cert_validation : r.fqdn
    if startswith(k, "${each.key}__")
  ]

  timeouts {
    create = each.value.cert_validation_timeout
  }
}
