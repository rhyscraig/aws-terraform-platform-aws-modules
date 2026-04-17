variable "vpc_name" {
  type        = string
  description = "Name for the VPC"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "environment" {
  type        = string
  description = "Environment name (prod, staging, dev)"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT Gateways for outbound internet access. Disabled by default - use VPC Endpoints instead for AWS services."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}
