################################################################################
# VPC Interface Endpoints
################################################################################
# Creates VPC interface endpoints with private DNS disabled for cross-account sharing
# Private DNS resolution is handled via Route53 private hosted zones

resource "aws_vpc_endpoint" "private" {
  for_each = var.eps_map

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value["name"]}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false # Required for cross-account/VPC sharing
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.if_security_group_id]

  tags = merge(
    var.default_tags,
    {
      Name        = "${var.environment}-${each.key}-endpoint"
      Service     = each.key
      Environment = var.environment
    }
  )
}


################################################################################
# Route53 Private Hosted Zones
################################################################################
# Creates private hosted zones for each VPC endpoint service

resource "aws_route53_zone" "private" {
  for_each = var.eps_map

  name = "${each.value["shortdns"]}.${var.region}.amazonaws.com"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(
    var.default_tags,
    {
      Name        = "${var.environment}-${each.key}-phz"
      Service     = each.key
      Environment = var.environment
    }
  )

  # Ignore VPC associations after creation (managed separately for spoke VPCs)
  lifecycle {
    ignore_changes = [vpc]
  }
}

################################################################################
# Route53 DNS Records
################################################################################
# Creates A records pointing to VPC endpoint DNS entries

resource "aws_route53_record" "private" {
  for_each = var.eps_map

  zone_id = aws_route53_zone.private[each.key].zone_id
  name    = "${each.value["shortdns"]}.${var.region}.amazonaws.com"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.private[each.key].dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.private[each.key].dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = false
  }
}

################################################################################
# Special Route53 Zones and Records
################################################################################

# EC2 API endpoint uses a different DNS pattern (ec2.region.api.aws)
resource "aws_route53_zone" "ec2api" {
  count = contains(keys(var.eps_map), "ec2") ? 1 : 0

  name = "ec2.${var.region}.api.aws"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(
    var.default_tags,
    {
      Name        = "${var.environment}-ec2-api-phz"
      Service     = "ec2-api"
      Environment = var.environment
    }
  )

  # Ignore VPC associations after creation
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_record" "ec2api" {
  count = contains(keys(var.eps_map), "ec2") ? 1 : 0

  zone_id = aws_route53_zone.ec2api[0].zone_id
  name    = "ec2.${var.region}.api.aws"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.private["ec2"].dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.private["ec2"].dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = false
  }
}

# ECR DKR endpoint needs a wildcard record for account-specific repositories
resource "aws_route53_record" "ecrdkrwildcard" {
  count = contains(keys(var.eps_map), "ecr-dkr") ? 1 : 0

  zone_id = aws_route53_zone.private["ecr-dkr"].zone_id
  name    = "*.dkr.ecr.${var.region}.amazonaws.com"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.private["ecr-dkr"].dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.private["ecr-dkr"].dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = false
  }
}