# NAT Instances Module

⚠️ **ARCHIVED: Not recommended for web workloads**

This module is provided for reference only. For modern web-only applications, you don't need NAT infrastructure at all—see the vpc-standard module documentation for zero-cost architecture.

---

Cost-effective replacement for AWS managed NAT Gateways. Reduces NAT egress costs by ~85% for non-production workloads.

## Cost Comparison

| Component | NAT Gateway | NAT Instance |
|-----------|-------------|--------------|
| Hourly charge | $0.045 × 3 AZ = $32.4/mo | $0 |
| EC2 instance (t3a.nano) | N/A | ~$3-5/mo |
| Data processing | $0.45/GB | $0.09/GB |
| **Total (100 GB/mo)** | **$78/mo** | **$12-15/mo** |

## Usage

### 1. Configure vpc-standard to disable NAT Gateways

```hcl
module "vpc" {
  source = "git::https://github.com/rhyscraig/aws-terraform-platform-aws-modules.git//modules/vpc-standard?ref=v2.0.0"

  vpc_name             = "vpc-prod-core"
  cidr_block           = "10.0.0.0/16"
  environment          = "prod"
  enable_nat_gateway   = false  # <-- Disable managed NAT Gateways
  
  tags = {
    ManagedBy = "Terraform"
  }
}
```

### 2. Deploy NAT instances

```hcl
module "nat_instances" {
  source = "git::https://github.com/rhyscraig/aws-terraform-platform-aws-modules.git//modules/nat-instances?ref=v2.0.0"

  vpc_id                = module.vpc.vpc_id
  public_subnets       = module.vpc.public_subnets
  private_subnets      = module.vpc.private_subnets
  private_subnet_cidrs = module.vpc.private_subnets_cidrs

  # Sizing options
  instance_type    = "t3a.nano"      # or t3a.micro for higher throughput
  desired_capacity = 1                # 1 instance per AZ for HA
  min_size         = 1
  max_size         = 3

  tags = {
    ManagedBy = "Terraform"
  }
}
```

## How It Works

1. **NAT Instance ASG**: Deploys 1-3 EC2 instances (default: 1) in public subnets
2. **Security Group**: Accepts traffic from private subnets, routes outbound through instance
3. **Route Tables**: Creates custom route tables for private subnets pointing to NAT instance ENIs
4. **iptables NAT**: Linux kernel iptables configured to MASQUERADE outbound traffic

## Instance Type Selection

| Type | vCPU | Memory | Network | Cost/mo | Use Case |
|------|------|--------|---------|---------|----------|
| t3a.nano | 2 | 0.5 GB | 5 Gbps | $3 | Dev, test, light workloads |
| t3a.micro | 2 | 1 GB | 10 Gbps | $5 | Small production |
| t3a.small | 2 | 2 GB | 5 Gbps | $8 | Medium production |

**Recommendation**: Start with `t3a.nano` for development, `t3a.micro` for production with sufficient monitoring.

## High Availability (HA)

For production workloads, run 3 instances (one per AZ):

```hcl
desired_capacity = 3  # One NAT instance per AZ
min_size         = 3
max_size         = 3
```

This ensures failover capability if one instance fails. Routes are updated dynamically to the remaining healthy instances.

## Monitoring & Alarms

After deployment, monitor these metrics:

```bash
# Network In/Out
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

Set up CloudWatch alarms for:
- **High Network Out** (>100 Mbps sustained) → Scale up instance type
- **CPU** (>70% sustained) → Scale up instance type
- **Instance Unhealthy** → ASG will auto-replace

## Limitations

1. **NAT instance failover** is slower than NAT Gateway (ASG scale/route update ~1 min vs instant)
2. **Throughput** is limited by instance network performance (5-10 Gbps for t3a)
3. **Egress filtering** is not built-in (use security groups if needed)
4. **Source IP** depends on instance availability (may change if instance replaced)

For applications requiring strict source IP stability, use NAT Gateway or Elastic IP.

## Cost Optimization Tips

1. **Use VPC Endpoints** for S3, DynamoDB, Systems Manager → bypass NAT entirely
2. **Regional endpoints** reduce cross-region NAT traffic
3. **CloudFront** for frequent egress to internet → cache locally
4. **NAT instance shutdown hours** during off-peak (schedule ASG to 0 capacity)

## Migration from NAT Gateway

```bash
# 1. Deploy module with enable_nat_gateway = false
# 2. Deploy nat-instances module
# 3. Verify traffic routes through instances
# 4. Delete NAT Gateways from AWS console (Terraform will auto-delete if remove from code)
# 5. Release Elastic IPs
```

## Security

- **IMDSv2 only** enforced (no IMDSv1)
- **Minimal IAM permissions** (only route table updates for failover)
- **Security group** locks inbound to private subnet CIDRs only
- **No public IP** on NAT instances (uses source instance ENI)

## Troubleshooting

**Private instances can't reach internet:**
```bash
# Check route tables were created
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=nat-private-rt-*"

# Verify NAT instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=nat-instance" \
  "Name=instance-state-name,Values=running"

# Test connectivity from private instance
aws ssm start-session --target <private-instance-id>
# Inside: curl -I https://google.com
```

**High latency to internet:**
- Check NAT instance CPU/network utilization
- Consider upgrading instance type
- Verify SecurityGroup allows all outbound protocols

**Cost still high:**
- Monitor data transfer via CloudWatch
- May indicate application bug (retries, logging to external service)
- Consider VPC Endpoints for common services
