# VPC Standard Module

Production-ready VPC with security-first defaults and zero internet NAT costs.

## Features

- **Dynamic AZ selection** - Works across all AWS regions (fixes eu-west-2 support)
- **VPC Flow Logs enabled** - CloudWatch integration for network monitoring
- **No NAT by default** - Use VPC Endpoints for AWS services (S3, DynamoDB, etc.)
- **3-tier networking** - Public and private subnets across 3 AZs
- **IMDSv2 ready** - Supports IMDSv2-only EC2 instances

## Cost Optimized for Web Workloads

**Default Configuration (Zero Internet NAT Cost)**
- No NAT Gateways (saves $32-96/month)
- No NAT Instances (saves $3-15/mo)
- VPC Flow Logs only (CloudWatch pricing for logs)

Web applications typically don't need outbound internet access:
- Static assets served by CloudFront (not internet-facing compute)
- Backend APIs use VPC Endpoints for AWS services
- Database access is internal (no outbound needed)
- Monitoring via CloudWatch (no third-party agents)

## Usage

### Minimal Example (Recommended)

```hcl
module "vpc" {
  source = "git::https://github.com/rhyscraig/aws-terraform-platform-aws-modules.git//modules/vpc-standard?ref=v2.0.0"

  vpc_name    = "vpc-prod-core"
  cidr_block  = "10.0.0.0/16"
  environment = "prod"

  tags = {
    ManagedBy = "Terraform"
    Team      = "Platform"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}
```

### With Optional Internet NAT (if needed later)

```hcl
module "vpc" {
  source = "git::https://github.com/rhyscraig/aws-terraform-platform-aws-modules.git//modules/vpc-standard?ref=v2.0.0"

  vpc_name           = "vpc-prod-core"
  cidr_block         = "10.0.0.0/16"
  environment        = "prod"
  enable_nat_gateway = true  # Enable if workload truly needs internet

  tags = {
    ManagedBy = "Terraform"
  }
}
```

## Web Workloads: Zero Outbound Architecture

For web-only applications, **no outbound access needed at all**:

```
┌─────────────────────────────┐
│  CloudFront (Edge)          │ ← Handles inbound requests
│  (Serves static content)    │
└──────────────┬──────────────┘
               │ (Internal, no internet access needed)
┌──────────────▼──────────────┐
│  Application (Private VPC)  │
│  - Web server / container   │
│  - Database connection      │
│  - CloudWatch logs (via SDK)│
│  → No internet access       │
└─────────────────────────────┘
```

**Why no outbound access needed:**
- ✓ Static assets served by CloudFront (edge, not your compute)
- ✓ Database is internal (no outbound to database needed)
- ✓ CloudWatch logging uses AWS SDK (AWS API calls are internal to AWS)
- ✓ No third-party integrations (if you add them later, reconsider design)
- ✓ No SSH/RDP needed (use AWS Systems Manager Fleet Manager for rare ops access)

**Cost: $0/month** (no NAT, no endpoints)

### If You Later Need Outbound Internet

Only enable if you add non-web workloads:

```hcl
enable_nat_gateway = true
# For prod: 3 gateways ($96/month)
# For non-prod: 1 gateway ($32/month)
```

**Cost**: $32-96/month + $0.45/GB data transfer

## Networking Architecture

```
┌─────────────────────────────────────┐
│          VPC: 10.0.0.0/16           │
├──────────┬──────────┬───────────────┤
│ AZ-1     │ AZ-2     │ AZ-3          │
├──────────┼──────────┼───────────────┤
│ Public   │ Public   │ Public        │
│ 10.0.48/26  10.1.48/26  10.2.48/26 │
│          │          │               │
│ Private  │ Private  │ Private       │
│ 10.0.0/22 10.1.0/22 10.2.0/22      │
└──────────┴──────────┴───────────────┘

Flow Logs → CloudWatch Logs
```

## Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vpc_name` | string | - | Name for the VPC (required) |
| `cidr_block` | string | - | CIDR block for VPC (required) |
| `environment` | string | - | Environment (prod/staging/dev) |
| `enable_nat_gateway` | bool | false | Enable NAT Gateways (not recommended) |
| `tags` | map(string) | {} | Common tags for resources |

## Output Values

```hcl
vpc_id                 # VPC ID
vpc_cidr               # VPC CIDR block
private_subnets       # List of private subnet IDs
public_subnets        # List of public subnet IDs
private_subnets_cidrs # List of private subnet CIDR blocks
nat_gateway_ids       # NAT Gateway IDs (empty if disabled)
```

## VPC Endpoints Setup

Once VPC is created, add Gateway and Interface endpoints:

### S3 Gateway Endpoint (Free)

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = [
    aws_route_table.private[*].id
  ]

  tags = {
    Name = "s3-endpoint"
  }
}
```

### Systems Manager Interface Endpoints

```hcl
locals {
  ssm_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(local.ssm_services)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${each.value}-endpoint"
  }
}
```

## Cost Analysis

| Scenario | Monthly Cost |
|----------|------------|
| **No NAT + VPC Endpoints** | $7-10 (SSM endpoints only) |
| **No NAT + No Endpoints** | $0 (if app doesn't need outbound) |
| **NAT Gateway (non-prod)** | $32 + data transfer costs |
| **NAT Gateway (prod)** | $96 + data transfer costs |

### Example: 100GB/month Data Transfer

| Method | Cost |
|--------|------|
| VPC Endpoint (S3) | $0 |
| NAT Gateway | $45 (transfer) + $96 (gateways) = $141 |
| Savings | **$141/month** |

## Flow Logs

VPC Flow Logs are enabled by default (security requirement). Cost is minimal:
- CloudWatch Logs pricing: ~$0.50/GB
- Typical VPC: 1-5 GB/month = $0.50-2.50/month

## Region Considerations

This module dynamically selects AZs for any AWS region:

```bash
# Works in all regions automatically
terraform apply -var-file=eu-west-2.tfvars  # London
terraform apply -var-file=us-east-1.tfvars  # N. Virginia
terraform apply -var-file=ap-southeast-1.tfvars  # Singapore
```

Previously hardcoded `us-east-1a/b/c` has been fixed.

## Security Best Practices

1. **Enable VPC Flow Logs** ✓ (done automatically)
2. **Use private subnets** for compute (no public IPs)
3. **Use Systems Manager Session Manager** instead of SSH/RDP
4. **Block internet access** except where explicitly needed (principle of least privilege)
5. **Use NACLs** to restrict traffic between subnets if needed

## Troubleshooting

**Private instances can't reach S3:**
- Verify S3 Gateway endpoint is created
- Check route table has endpoint route
- Verify security group allows port 443

**High CloudWatch log costs:**
- Reduce flow log sampling: `flow_log_traffic_type = "REJECT"` (log denies only)
- Set retention: `retention_in_days = 7`

**Need internet access:**
- Option 1: Create NAT Gateway (set `enable_nat_gateway = true`)
- Option 2: Create NAT instances (advanced, cost-optimized)
- Option 3: Use CloudFront or ALB for specific services

## Version Compatibility

- Terraform >= 1.0
- AWS Provider >= 5.0
- terraform-aws-modules/vpc/aws >= 6.0
