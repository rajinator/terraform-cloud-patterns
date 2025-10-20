# VPC Endpoints Module

This module creates VPC interface endpoints, Route53 private hosted zones, and manages cross-VPC zone associations for centralized endpoint sharing.

## Overview

The endpoints module is the core of the centralized VPC endpoints solution. It creates:

1. **VPC Interface Endpoints** - With `private_dns_enabled = false` to allow sharing
2. **Route53 Private Hosted Zones** - Custom DNS zones for each service
3. **DNS Records** - A records pointing to endpoint DNS entries
4. **VPC Association Authorizations** - Allow spoke VPCs to associate with zones

## Features

- Dynamic endpoint creation based on configuration map
- Automatic Route53 private hosted zone creation per endpoint
- Support for special endpoint configurations (EC2 API, ECR wildcard)
- Cross-account/VPC zone association authorization
- Conditional resource creation (e.g., EC2 API zone only if EC2 endpoint exists)
- Comprehensive outputs for downstream automation

## Resources Created

### VPC Endpoints
- `aws_vpc_endpoint.private` - Interface endpoints for AWS services

### Route53 Resources
- `aws_route53_zone.private` - Private hosted zones for each endpoint
- `aws_route53_zone.ec2api` - Special zone for EC2 API endpoint
- `aws_route53_record.private` - DNS A records for each endpoint
- `aws_route53_record.ec2api` - DNS A record for EC2 API
- `aws_route53_record.ecrdkrwildcard` - Wildcard record for ECR repositories

### Zone Associations
- `aws_route53_vpc_association_authorization.spoke_vpcs` - Authorization for spoke VPCs
- `aws_route53_vpc_association_authorization.spoke_vpcs_ec2api` - Authorization for EC2 API zone

## Usage

```hcl
module "vpc_endpoints" {
  source = "./modules/endpoints"

  vpc_id               = "vpc-0123456789abcdef0"
  region               = "us-east-1"
  private_subnet_ids   = ["subnet-123", "subnet-456"]
  private_vpc_rtbs     = ["rtb-123"]
  if_security_group_id = "sg-0123456789abcdef0"
  
  multi_account_vpc_cidrs = ["10.0.0.0/16", "10.1.0.0/16"]
  
  vpcs_map = {
    "production" = "vpc-prod123"
    "staging"    = "vpc-stag123"
  }
  
  eps_map = {
    "ec2" = {
      name     = "ec2"
      shortdns = "ec2"
    }
    "ecr-dkr" = {
      name     = "ecr.dkr"
      shortdns = "dkr.ecr"
    }
  }
  
  environment  = "shared-services"
  default_tags = {
    ManagedBy = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `vpc_id` | VPC ID where endpoints will be created | `string` | Yes | - |
| `region` | AWS region | `string` | Yes | - |
| `private_subnet_ids` | Subnet IDs for endpoint ENIs (min 2) | `list(string)` | Yes | - |
| `private_vpc_rtbs` | Route table IDs for gateway endpoints | `list(string)` | Yes | - |
| `if_security_group_id` | Security group ID for endpoints | `string` | Yes | - |
| `multi_account_vpc_cidrs` | CIDR blocks from spoke VPCs | `list(string)` | Yes | - |
| `vpcs_map` | Map of VPC names to IDs for associations | `map(string)` | Yes | - |
| `eps_map` | Map of endpoint configurations | `map(object)` | Yes | - |
| `environment` | Environment name | `string` | Yes | - |
| `default_tags` | Default tags | `map(string)` | No | `{}` |

### Endpoint Map Structure

The `eps_map` variable defines which endpoints to create:

```hcl
eps_map = {
  "endpoint-key" = {
    name     = "aws-service-name"  # Used in service endpoint URL
    shortdns = "dns-prefix"        # Used in private hosted zone name
  }
}
```

**Examples**:

```hcl
"ec2" = {
  name     = "ec2"
  shortdns = "ec2"
}
# Creates: com.amazonaws.us-east-1.ec2
# Zone: ec2.us-east-1.amazonaws.com

"ecr-api" = {
  name     = "ecr.api"
  shortdns = "api.ecr"
}
# Creates: com.amazonaws.us-east-1.ecr.api
# Zone: api.ecr.us-east-1.amazonaws.com

"logs" = {
  name     = "logs"
  shortdns = "logs"
}
# Creates: com.amazonaws.us-east-1.logs
# Zone: logs.us-east-1.amazonaws.com
```

## Outputs

| Name | Description | Type |
|------|-------------|------|
| `phz_zones` | Map of private hosted zones | `map(object)` |
| `phz_ec2api` | EC2 API private hosted zone | `object` |
| `vpc_endpoints` | Map of VPC endpoints | `map(object)` |

### Output Structure Examples

```hcl
# phz_zones output
{
  "ec2" = {
    zone_id = "Z1234567890ABC"
    name    = "ec2.us-east-1.amazonaws.com"
  }
  "logs" = {
    zone_id = "Z0987654321XYZ"
    name    = "logs.us-east-1.amazonaws.com"
  }
}

# vpc_endpoints output
{
  "ec2" = {
    id           = "vpce-0123456789abcdef0"
    arn          = "arn:aws:ec2:us-east-1:123456789012:vpc-endpoint/vpce-0123456789abcdef0"
    service_name = "com.amazonaws.us-east-1.ec2"
    dns_entry    = [...]
  }
}
```

## Special Endpoint Configurations

### EC2 API Endpoint

The EC2 service has two DNS patterns:
1. Standard: `ec2.us-east-1.amazonaws.com`
2. API specific: `ec2.us-east-1.api.aws`

This module creates both zones when the EC2 endpoint is configured.

### ECR Docker Endpoint

ECR repositories use account-specific DNS names like `123456789012.dkr.ecr.us-east-1.amazonaws.com`. The module creates a wildcard DNS record `*.dkr.ecr.us-east-1.amazonaws.com` to handle all account repositories.

### S3 Considerations

- **S3 Gateway Endpoints**: Cannot be shared across VPCs
- **S3 Interface Endpoints**: Can be shared but incur data processing charges
- Decision depends on your cost vs. centralization requirements

## VPC Association Workflow

1. **Central Account** (This module):
   - Creates VPC endpoints and private hosted zones
   - Authorizes spoke VPCs for zone association
   
2. **Spoke Account** (Manual or separate Terraform):
   - Associates spoke VPC with the authorized zones

### Example Spoke VPC Association

From the spoke account, run:

```bash
aws route53 associate-vpc-with-hosted-zone \
  --hosted-zone-id Z1234567890ABC \
  --vpc VPCRegion=us-east-1,VPCId=vpc-spokevpc123
```

Or use Terraform:

```hcl
resource "aws_route53_zone_association" "spoke" {
  zone_id = "Z1234567890ABC"  # From central account output
  vpc_id  = "vpc-spokevpc123"
}
```

## Supported AWS Services

Common services with VPC endpoint support:

### Compute & Containers
- EC2, ECS, ECS Agent, ECS Telemetry, EKS, Lambda, App Runner

### Storage
- S3, EBS, EFS, FSx, Backup

### Database
- RDS, RDS Data API, DynamoDB, ElastiCache, Neptune, QLDB, Timestream

### Networking
- Elastic Load Balancing, VPC Lattice, Global Accelerator, API Gateway

### Security & Identity
- KMS, Secrets Manager, SSM, SSM Messages, STS, IAM, CloudHSM

### Developer Tools
- CodeCommit, CodeBuild, CodeDeploy, CodePipeline, CodeArtifact

### Monitoring & Logging
- CloudWatch, CloudWatch Logs, X-Ray

### Messaging
- SNS, SQS, Kinesis Data Streams, Kinesis Firehose, EventBridge

### Application Integration
- Step Functions, App Mesh, AppConfig

### Machine Learning
- SageMaker (Runtime, Notebook, API)

For the complete list, see [AWS services that integrate with AWS PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-privatelink-support.html).

## Advanced Usage

### Adding a New Endpoint

To add a new AWS service endpoint:

1. Update `terraform.tfvars`:

```hcl
eps_map = {
  # ... existing endpoints ...
  
  "sns" = {
    name     = "sns"
    shortdns = "sns"
  }
}
```

2. Apply changes:

```bash
terraform apply
```

3. Associate spoke VPCs with the new zone (from spoke accounts)

### Removing an Endpoint

1. Remove from `eps_map` in `terraform.tfvars`
2. Disassociate spoke VPCs from the zone first (from spoke accounts)
3. Run `terraform apply` to destroy the endpoint and zone

## Lifecycle Management

### Zone Association Lifecycle

The Route53 zones use `lifecycle.ignore_changes = [vpc]` to prevent Terraform from managing VPC associations after creation. This is intentional because:

1. Initial VPC association is created for the central VPC
2. Spoke VPC associations are managed separately (from spoke accounts)
3. Terraform shouldn't remove spoke associations when it runs

### Resource Dependencies

- Security group must exist before endpoints
- Endpoints must exist before Route53 zones
- Zones must exist before zone associations

Dependencies are managed through explicit `depends_on` where necessary.

## Troubleshooting

### Issue: Endpoint Creation Fails

**Possible Causes**:
- Service not available in the region
- Insufficient subnet availability
- Security group doesn't exist

**Solution**:
```bash
# Check service availability
aws ec2 describe-vpc-endpoint-services --region us-east-1 | grep <service-name>

# Verify subnets
aws ec2 describe-subnets --subnet-ids subnet-123 subnet-456
```

### Issue: DNS Resolution Not Working in Spoke VPC

**Check**:
1. VPC association completed: `aws route53 list-hosted-zones-by-vpc --vpc-id <vpc-id>`
2. DNS settings enabled: `enableDnsSupport` and `enableDnsHostnames`
3. Route tables configured for VPC peering

### Issue: Wildcard Record Not Working for ECR

Ensure the ECR endpoint is included in `eps_map` as `"ecr-dkr"`. The wildcard record is only created when this endpoint exists.

## Cost Optimization

### Endpoint Costs
- **Hourly charge**: ~$0.01/hour per endpoint per AZ
- **Data processing**: ~$0.01/GB

### Optimization Tips
1. Only create endpoints for services you actually use
2. Remove unused endpoints regularly
3. Deploy across minimum required AZs (typically 2-3)
4. Monitor data transfer with CloudWatch

### Cost Monitoring

```bash
# Get endpoint usage metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/PrivateLinkEndpoints \
  --metric-name BytesProcessed \
  --dimensions Name=Endpoint,Value=vpce-xxx \
  --start-time 2024-10-01T00:00:00Z \
  --end-time 2024-10-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

## Security Best Practices

1. **Enable VPC Flow Logs**: Monitor traffic to/from endpoints
2. **Use Security Groups**: Restrict access to known CIDR blocks only
3. **Enable Endpoint Policies**: Further restrict API actions (not implemented in this module)
4. **Audit Zone Associations**: Regularly review which VPCs have access
5. **Rotate Security Group Rules**: Update CIDR blocks as VPCs change

## Additional Resources

- [AWS PrivateLink Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/)
- [Route53 Private Hosted Zones](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html)
- [VPC Endpoint Policies](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html)

