output "nat_security_group_id" {
  value       = aws_security_group.nat.id
  description = "Security group ID of NAT instances"
}

output "nat_instance_ids" {
  value       = aws_autoscaling_group.nat.*.id
  description = "ASG IDs for NAT instances"
}

output "private_route_table_ids" {
  value       = aws_route_table.private[*].id
  description = "Route table IDs for private subnets"
}

output "nat_eni_ids" {
  value       = aws_network_interface.nat[*].id
  description = "ENI IDs used by NAT instances"
}
