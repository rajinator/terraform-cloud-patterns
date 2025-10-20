# Security Module

This module creates and manages security resources for VPC endpoints, including security groups and network ACLs.

## Overview

The security module provisions security groups with appropriate ingress and egress rules to allow traffic from spoke VPCs to the centralized VPC endpoints. It follows the principle of least privilege by only allowing HTTPS traffic (port 443) from specified CIDR blocks.

## Features

- Creates a dedicated security group for VPC endpoint access
- Configures ingress rules for HTTPS (port 443) from spoke VPCs
- Configures egress rules for response traffic back to spoke VPCs
- Supports dynamic tagging
- Uses `name_prefix` for security group naming to support recreation

## Resources Created

- `aws_security_group.vpcendpoints_access` - Security group for VPC endpoints
- `aws_security_group_rule.vpcendpoints_access_ingress_https` - HTTPS ingress rule
- `aws_security_group_rule.vpcendpoints_access_egress` - Egress rule for responses

## Usage

```hcl
module "security" {
  source = "./modules/security"

  vpc_id                  = "vpc-0123456789abcdef0"
  region                  = "us-east-1"
  private_subnet_ids      = ["subnet-123", "subnet-456"]
  multi_account_vpc_cidrs = ["10.0.0.0/16", "10.1.0.0/16"]
  environment             = "shared-services"
  default_tags            = {
    ManagedBy = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `vpc_id` | VPC ID where security resources will be created | `string` | Yes | - |
| `region` | AWS region | `string` | Yes | - |
| `private_subnet_ids` | List of private subnet IDs | `list(string)` | Yes | - |
| `multi_account_vpc_cidrs` | CIDR blocks from spoke VPCs that need access | `list(string)` | Yes | - |
| `environment` | Environment name for resource naming | `string` | Yes | - |
| `default_tags` | Default tags to apply to all resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description | Type |
|------|-------------|------|
| `vpcendpoints_access` | Security group resource for VPC endpoint access | `object` |

## Security Considerations

### Ingress Rules

- **Protocol**: TCP
- **Port**: 443 (HTTPS)
- **Source**: Spoke VPC CIDR blocks only
- **Rationale**: VPC interface endpoints use HTTPS for secure communication

### Egress Rules

- **Protocol**: All
- **Port**: All
- **Destination**: Spoke VPC CIDR blocks only
- **Rationale**: Allow response traffic back to originating resources

### Best Practices

1. **Principle of Least Privilege**: Only specified CIDR blocks are allowed
2. **Separate Security Groups**: Dedicated SG for endpoints, separate from application resources
3. **Descriptive Rules**: Each rule includes a description for auditing
4. **Immutable Names**: Using `name_prefix` allows for blue-green deployments

## Network ACLs

The module includes a placeholder for Network ACL configuration (`nacls.tf`). Currently, NACLs are not configured as security groups provide sufficient control. You can extend this module to add NACL rules if required by your compliance or security policies.

## Example: Adding Custom Rules

If you need to add custom rules (e.g., for specific ports or protocols), you can extend the module:

```hcl
# In security_groups.tf, add:
resource "aws_security_group_rule" "custom_ingress" {
  type              = "ingress"
  description       = "Allow custom protocol"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.multi_account_vpc_cidrs
  security_group_id = aws_security_group.vpcendpoints_access.id
}
```

## Troubleshooting

### Issue: Cannot Connect to Endpoints from Spoke VPC

**Check**:
1. Verify CIDR blocks are correctly specified in `multi_account_vpc_cidrs`
2. Ensure spoke VPC route tables have routes to the central VPC
3. Confirm Network ACLs in both VPCs allow traffic on port 443

### Issue: Security Group Rule Limit Exceeded

**Solution**:
If you have many spoke VPCs, you may hit the 60-rule limit per security group. Consider:
- Aggregating CIDR blocks where possible
- Creating multiple security groups and attaching them to endpoints
- Using AWS prefix lists to group CIDR blocks

## Additional Resources

- [AWS Security Groups Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [VPC Endpoint Security](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html)

