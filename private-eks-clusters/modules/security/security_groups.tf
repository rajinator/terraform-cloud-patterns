# use the selected vpc as a tf data source
data "aws_vpc" "selected" {
    id = var.vpc_id
}

# SG to allow ssh access to EKS workers from the VPC CIDR
resource "aws_security_group" "worker_group_mgmt_sg" {
  name_prefix = "worker_group_mgmt_sg"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      data.aws_vpc.selected.cidr_block,
    ]
  }
  tags = merge(
    var.common_tags,
    {
      Component = "Kubernetes"
    }
  )
}

# create the eksworkers_self security group
resource "aws_security_group" "eksworkers_self" {
  name        = "eksworkers_self"
  description = "Default additional SG to create to attach to EKS workers"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(
    var.common_tags,
    {
      Component = "Kubernetes"
    }
  )
}

# create ingress rule in eksworkers_self to allow ingress to workers from VPC cidr block
resource "aws_security_group_rule" "eksworkers_self_default_vpc_ingress" {
  depends_on        = [aws_security_group.eksworkers_self]
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.eksworkers_self.id
}

# create egress rule in eksworkers_self to allow egress from workers to the VPC cidr block
resource "aws_security_group_rule" "eksworkers_self_default_vpc_egress" {
  depends_on        = [aws_security_group.eksworkers_self]
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.eksworkers_self.id
}

# Create SG for VPC endpoints
resource "aws_security_group" "vpcendpoints_access" {
  name        = "vpcendpoints_access"
  description = "Default additional SG to create to attach to EKS workers"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(
    var.common_tags,
    {
      Component = "Endpoints"
    }
  )
}

# create ingress rule in vpcendpoints_access sg to allow traffic to vpc endpoints from the vpc cidr block
resource "aws_security_group_rule" "vpcendpoints_access_ingress" {
  depends_on        = [aws_security_group.vpcendpoints_access]
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.vpcendpoints_access.id
}

# create egress rule in vpcendpoints_access to allow response from vpc endpoints to the VPC cidr block
resource "aws_security_group_rule" "vpcendpoints_access_response" {
  depends_on        = [aws_security_group.vpcendpoints_access]
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.vpcendpoints_access.id
}