variable "vpc_id" {
  type        = string
  description = "VPC ID where NAT instances will be deployed"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet IDs where NAT instances will run (one per AZ)"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet IDs that will route through NAT instances"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks of private subnets (for ingress to NAT instances)"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for NAT instances"
  default     = "t3a.nano" # ~$3-4/month per instance
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of NAT instances"
  default     = 1
}

variable "min_size" {
  type        = number
  description = "Minimum number of NAT instances"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum number of NAT instances"
  default     = 3
}

variable "tags" {
  type        = map(string)
  description = "Common tags for resources"
  default     = {}
}
