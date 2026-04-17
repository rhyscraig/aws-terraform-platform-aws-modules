data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use the first 3 available AZs in whatever region the provider is configured for.
  # This avoids the previous hardcoding of us-east-1a/b/c which broke eu-west-2 deployments.
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = var.vpc_name
  cidr = var.cidr_block

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.cidr_block, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.cidr_block, 8, k + 48)]

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.enable_nat_gateway && var.environment != "prod"
  enable_dns_hostnames = true

  # Security: Flow Logs Enabled by Default
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = var.tags
}
