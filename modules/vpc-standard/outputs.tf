output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs"
}

output "private_subnets_cidrs" {
  value       = module.vpc.private_subnets_cidr_blocks
  description = "CIDR blocks of private subnets"
}

output "nat_gateway_ids" {
  value       = module.vpc.natgw_ids
  description = "NAT Gateway IDs (empty if enable_nat_gateway = false)"
}
