module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.cidr_block

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.cidr_block, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.cidr_block, 8, k + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod"
  enable_dns_hostnames = true

  # Security: Flow Logs Enabled by Default
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = var.tags
}
locals { azs = ["eu-west-2a", "eu-west-2b", "eu-west-2c"] }
