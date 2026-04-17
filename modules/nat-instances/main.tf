# NAT Instances Module
# Provides cost-effective outbound NAT for private subnets using EC2 instances
# instead of managed NAT Gateways. Reduces egress costs from $0.45/GB + $32/month per gateway
# to ~$0.09/GB + minimal EC2 costs (~$10-15/month for small ASG).
#
# This module is designed to replace NAT Gateways for non-production workloads or
# cost-sensitive environments. For production, use with NAT instance failover or
# pair with VPC endpoints for critical services (S3, DynamoDB, etc.).

# Get the latest Amazon Linux 2 NAT AMI for this region
data "aws_ami" "nat_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for NAT instances
resource "aws_security_group" "nat" {
  name_prefix = "nat-instance-"
  description = "Security group for NAT instances"
  vpc_id      = var.vpc_id

  # Inbound: Accept all traffic from private subnets
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = var.private_subnet_cidrs
  }

  # Outbound: Allow all (default for NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "nat-instance-sg"
  })
}

# IAM role for NAT instances (minimal permissions)
resource "aws_iam_role" "nat" {
  name_prefix = "nat-instance-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Allow NAT instances to modify their own route table (for HA failover)
resource "aws_iam_role_policy" "nat_ec2_policy" {
  name_prefix = "nat-ec2-"
  role        = aws_iam_role.nat.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ReplaceRoute",
          "ec2:DescribeRouteTables"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "nat" {
  name_prefix = "nat-instance-"
  role        = aws_iam_role.nat.name
}

# Launch template for NAT instances
resource "aws_launch_template" "nat" {
  name_prefix   = "nat-"
  image_id      = data.aws_ami.nat_ami.id
  instance_type = var.instance_type

  # Enable NAT on the instance
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Enable IP forwarding and configure NAT
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
    sysctl -p

    # Configure iptables for NAT
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables-save > /etc/iptables/rules.v4

    # Enable the NAT rules to persist after reboot
    echo "#!/bin/bash" > /etc/network/if-pre-up.d/iptables
    echo "iptables-restore < /etc/iptables/rules.v4" >> /etc/network/if-pre-up.d/iptables
    chmod +x /etc/network/if-pre-up.d/iptables
  EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.nat.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.nat.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "nat-instance"
    })
  }
}

# Auto Scaling Group for NAT instances (one per AZ)
resource "aws_autoscaling_group" "nat" {
  name_prefix         = "nat-asg-"
  vpc_zone_identifier = var.public_subnets
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.nat.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "nat-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create custom route tables for private subnets pointing to NAT instances
# Route traffic through the NAT instance ENIs instead of NAT Gateways
resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = var.vpc_id

  # Default route through NAT instance in the same AZ
  route {
    destination_cidr_block = "0.0.0.0/0"
    network_interface_id   = aws_network_interface.nat[count.index].id
  }

  tags = merge(var.tags, {
    Name = "nat-private-rt-${count.index}"
  })
}

# Associate private subnets with the new route tables
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = var.private_subnets[count.index]
  route_table_id = aws_route_table.private[count.index].id
}

# ENI for each NAT instance (static for failover capability)
resource "aws_network_interface" "nat" {
  count           = length(var.public_subnets)
  subnet_id       = var.public_subnets[count.index]
  security_groups = [aws_security_group.nat.id]

  tags = merge(var.tags, {
    Name = "nat-eni-${count.index}"
  })
}
