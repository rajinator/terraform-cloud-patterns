################################################################################
# Security Group for VPC Endpoints
################################################################################

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_security_group" "vpcendpoints_access" {
  name_prefix = "${var.environment}-vpcendpoints-access-"
  description = "Security group to allow traffic to and from VPC Endpoint ENIs from spoke VPCs"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(
    var.default_tags,
    {
      Name        = "${var.environment}-vpcendpoints-access"
      Environment = var.environment
      Component   = "VPC-Endpoints"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Security Group Rules
################################################################################

# Allow ingress from spoke VPCs to VPC endpoints (HTTPS - port 443)
resource "aws_security_group_rule" "vpcendpoints_access_ingress_https" {
  type              = "ingress"
  description       = "Allow HTTPS traffic from spoke VPCs to VPC endpoints"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.multi_account_vpc_cidrs
  security_group_id = aws_security_group.vpcendpoints_access.id
}

# Allow all egress back to spoke VPCs (for responses)
resource "aws_security_group_rule" "vpcendpoints_access_egress" {
  type              = "egress"
  description       = "Allow response traffic from VPC endpoints back to spoke VPCs"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = var.multi_account_vpc_cidrs
  security_group_id = aws_security_group.vpcendpoints_access.id
}