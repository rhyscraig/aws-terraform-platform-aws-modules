variable "sites" {
  description = <<-EOT
    Map of sites to manage DNS + TLS for.  Key is a short identifier used in
    Terraform resource addresses (e.g. "craighoad", "terrorgems").

    Each object:
      domain                  — apex domain, e.g. "terrorgems.com"
      aliases                 — additional CloudFront aliases, e.g. ["www.terrorgems.com"]
      manage_registrar_ns     — when true, Terraform updates the NS records at the
                                Route53 Registrar automatically.  Requires the domain to
                                be registered in the same AWS account.
      cert_validation_timeout — how long to wait for ACM DNS validation (default 20m).
  EOT

  type = map(object({
    domain                  = string
    aliases                 = list(string)
    manage_registrar_ns     = optional(bool, true)
    cert_validation_timeout = optional(string, "20m")
  }))

  default = {}
}
