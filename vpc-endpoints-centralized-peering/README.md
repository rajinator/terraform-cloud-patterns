# Centralized VPC Endpoints with Cross-Account Sharing

This Terraform example demonstrates how to create centralized VPC endpoints in a shared services or network VPC and make them accessible to multiple spoke VPCs across different accounts or regions using VPC peering and Route53 private hosted zones.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Configuration](#configuration)
- [Outputs](#outputs)
- [Limitations](#limitations)

## Overview

In multi-account AWS architectures, it's common to have multiple VPCs that need private access to AWS services. Creating VPC endpoints in each VPC can be costly and difficult to manage. This solution creates centralized VPC endpoints in a central networking VPC and shares them across spoke VPCs using:

1. **VPC Peering** - Connects the central VPC with spoke VPCs
2. **VPC Interface Endpoints** - Provides private connectivity to AWS services
3. **Route53 Private Hosted Zones** - Enables DNS resolution across VPCs
4. **Security Groups** - Controls access to the endpoints

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Central/Network VPC                             │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                    VPC Interface Endpoints                     │     │
│  │  • EC2  • ELB  • ECR  • Logs  • STS  • Autoscaling             │     │
│  │  • RDS  • ElastiCache  • S3  • SSM  • Secrets Manager          │     │
│  └──────────────────────────────┬─────────────────────────────────┘     │
│                                 │                                       │
│  ┌──────────────────────────────▼───────────────────────────────┐       │
│  │            Route53 Private Hosted Zones                      │       │
│  │  • ec2.us-east-1.amazonaws.com                               │       │
│  │  • logs.us-east-1.amazonaws.com                              │       │
│  │  • ... (one per endpoint)                                    │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                         │
└─────────────────────────────┬─────────────────────────────────────────┬─┘
                              │                                         │
                 ┌────────────┴──────────┐                  ┌───────────▼─────────┐
                 │    VPC Peering        │                  │   VPC Peering       │
                 └────────────┬──────────┘                  └───────────┬─────────┘
                              │                                         │
        ┌─────────────────────▼──────────────────┐      ┌───────────────▼─────────┐
        │     Spoke VPC 1 (Production)           │      │  Spoke VPC 2 (Staging)  │
        │                                        │      │                         │
        │  • EC2 instances                       │      │  • EKS Clusters         │
        │  • Lambda functions                    │      │  • RDS Instances        │
        │  • Access AWS services via endpoints   │      │  • Private resources    │
        └────────────────────────────────────────┘      └─────────────────────────┘
```

### How It Works

1. **VPC Endpoints Creation**: Interface endpoints are created in the central VPC with `private_dns_enabled = false` to allow sharing
2. **Route53 Private Hosted Zones**: Created for each endpoint service (e.g., `ec2.us-east-1.amazonaws.com`)
3. **DNS Records**: A records point to the endpoint's DNS names
4. **VPC Association Authorization**: Spoke VPCs are authorized to associate with the private hosted zones
5. **Cross-VPC DNS Resolution**: Resources in spoke VPCs can resolve AWS service DNS names to the centralized endpoints

## Features

- ✅ **Cost-Effective**: Create endpoints once, share across multiple VPCs
- ✅ **Centralized Management**: Single point of configuration and control
- ✅ **Multi-Account Support**: Works across AWS accounts with proper peering
- ✅ **Highly Available**: Endpoints deployed across multiple availability zones
- ✅ **Secure**: Security groups restrict access to authorized CIDR blocks only
- ✅ **Extensible**: Easy to add new endpoints by updating the configuration
- ✅ **Modular Design**: Separate modules for security and endpoints management

## Prerequisites

Before using this module, ensure you have:

### 1. AWS Infrastructure
- A central/network VPC with:
  - At least 2 private subnets in different availability zones
  - VPC peering established with spoke VPCs
  - Route tables configured for peering connections
- Spoke VPCs with:
  - VPC peering connections to the central VPC
  - Route table entries pointing to the central VPC

### 2. Terraform Setup
- Terraform >= 1.5.0
- AWS Provider ~> 5.0
- AWS credentials configured with appropriate permissions

### 3. Required IAM Permissions

The IAM user/role running Terraform needs permissions for:
- `ec2:CreateVpcEndpoint`, `ec2:DescribeVpcEndpoints`, `ec2:DeleteVpcEndpoint`
- `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:AuthorizeSecurityGroupEgress`
- `route53:CreateHostedZone`, `route53:DeleteHostedZone`, `route53:CreateVPCAssociationAuthorization`
- `route53:ChangeResourceRecordSets`, `route53:ListResourceRecordSets`

### 4. Network Configuration
- VPC CIDR blocks for all spoke VPCs (for security group rules)
- VPC IDs for spoke VPCs (for Route53 zone associations)

## Usage

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd vpc-endpoints-centralized-peering

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your actual values
vim terraform.tfvars
```

### Step 2: Configure Backend (Optional)

Create a `backend.hcl` file for remote state storage:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "vpc-endpoints-centralized/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

Initialize with backend:

```bash
terraform init -backend-config=backend.hcl
```

Or use the commented backend configuration in `versions.tf`.

### Step 3: Plan and Apply

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

### Step 4: Associate Spoke VPCs

After applying the configuration in the central account, you need to associate the spoke VPCs with the private hosted zones. Run this from each spoke account:

```bash
# For each private hosted zone, in each spoke VPC account
aws route53 associate-vpc-with-hosted-zone \
  --hosted-zone-id <zone-id-from-outputs> \
  --vpc VPCRegion=us-east-1,VPCId=<spoke-vpc-id>
```

Or use Terraform in the spoke account:

```hcl
resource "aws_route53_zone_association" "spoke" {
  zone_id = "<zone-id-from-central-account>"
  vpc_id  = "<spoke-vpc-id>"
}
```

### Step 5: Verify

Test DNS resolution from a resource in a spoke VPC:

```bash
# Test from an EC2 instance in a spoke VPC
nslookup ec2.us-east-1.amazonaws.com
nslookup logs.us-east-1.amazonaws.com

# Should resolve to private IPs in the central VPC
```

## Configuration

### Key Variables

| Variable | Description | Type | Required |
|----------|-------------|------|----------|
| `vpc_id` | Central VPC ID where endpoints will be created | string | Yes |
| `region` | AWS region | string | Yes |
| `private_subnet_ids` | List of private subnet IDs (min 2 for HA) | list(string) | Yes |
| `multi_account_vpc_cidrs` | CIDR blocks of spoke VPCs | list(string) | Yes |
| `vpcs_map` | Map of spoke VPC names to IDs | map(string) | Yes |
| `eps_map` | Map of endpoints to create | map(object) | Yes |
| `environment` | Environment name | string | No |
| `default_tags` | Default tags for resources | map(string) | No |

### Supported AWS Services

The following AWS services support VPC interface endpoints and can be configured:

- **Compute**: EC2, Lambda, ECS, Autoscaling
- **Storage**: S3 (interface), EBS
- **Database**: RDS, RDS Data API, ElastiCache, DynamoDB
- **Container**: ECR (API & DKR), EKS
- **Security**: KMS, Secrets Manager, SSM
- **Networking**: Elastic Load Balancing, VPC Lattice
- **Logging**: CloudWatch Logs
- **Identity**: STS
- **Messaging**: SNS, SQS
- **And many more...**

For a complete list, see [AWS PrivateLink services](https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-privatelink-support.html).

## Outputs

| Output | Description |
|--------|-------------|
| `phz_zones` | Map of private hosted zones with zone IDs |
| `phz_ec2api` | EC2 API private hosted zone details |
| `vpc_endpoints` | Map of created VPC endpoints with details |
| `security_group_id` | Security group ID attached to endpoints |

Example output usage:

```bash
# Get all zone IDs
terraform output phz_zones

# Get specific endpoint details
terraform output -json vpc_endpoints | jq '.ec2'
```

## Limitations

### Technical Limitations

1. **S3 Gateway Endpoints Cannot Be Shared**
   - S3 gateway endpoints are VPC-specific and cannot be shared
   - Use S3 interface endpoints for centralized access (incurs data processing charges)

2. **VPC Peering Required**
   - Spoke VPCs must have active VPC peering with the central VPC
   - Transitive peering is not supported (each spoke needs direct peering)

3. **Same Region Only**
   - VPC endpoints can only be accessed from VPCs in the same region
   - For multi-region setups, deploy separate endpoint stacks per region

4. **DNS Resolution**
   - Spoke VPCs must have DNS resolution and DNS hostnames enabled
   - Route53 Resolver forwarding rules may conflict with this setup

5. **Security Group Limits**
   - Security groups have a limit of 60 inbound/outbound rules
   - May need multiple security groups for large CIDR block lists

### Best Practices

- Deploy endpoints in at least 2 availability zones for high availability
- Use Transit Gateway instead of VPC peering for hub-and-spoke architectures with many VPCs
- Monitor endpoint usage with CloudWatch metrics
- Regularly review and update the list of endpoints based on actual usage
- Use Resource Access Manager (RAM) for sharing endpoints in AWS Organizations (alternative approach)

## Post-Deployment Steps

### 1. Test Connectivity

From resources in spoke VPCs:

```bash
# Test endpoint connectivity
curl https://ec2.us-east-1.amazonaws.com/ping
aws s3 ls  # Should use the centralized endpoint
```

### 2. Update Application Configurations

Ensure applications use AWS service endpoint URLs (not hardcoded IPs).

### 3. Monitor Usage

Enable VPC Flow Logs and CloudWatch metrics:

```bash
# Check endpoint metrics in CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/PrivateLinkEndpoints \
  --metric-name ActiveConnections \
  --dimensions Name=Endpoint,Value=<endpoint-id>
```

### 4. Document Zone IDs

Export and share the private hosted zone IDs with teams managing spoke VPCs:

```bash
terraform output -json phz_zones > zone-ids.json
```

## Troubleshooting

### Issue: DNS Resolution Fails in Spoke VPC

**Solution**:
1. Verify VPC association: `aws route53 list-hosted-zones-by-vpc --vpc-id <vpc-id>`
2. Check DNS settings: Ensure `enableDnsHostnames` and `enableDnsSupport` are true
3. Verify security group allows HTTPS (port 443) from spoke VPC CIDRs

### Issue: Connection Timeout to Endpoints

**Solution**:
1. Check VPC peering route tables
2. Verify security group rules allow traffic from spoke VPC CIDRs
3. Confirm Network ACLs aren't blocking traffic

### Issue: "Authorization Not Found" When Associating Zones

**Solution**:
1. Ensure `aws_route53_vpc_association_authorization` was created
2. Check that you're using the correct zone ID
3. Verify cross-account IAM permissions are set up correctly

## Clean Up

To destroy all resources:

```bash
# First, disassociate spoke VPCs from hosted zones (from spoke accounts)
# Then destroy resources in the central account
terraform destroy
```

**Warning**: This will delete all VPC endpoints and Route53 zones. Ensure spoke VPCs are disassociated first to avoid errors.

## Module Structure

```
.
├── main.tf                    # Main configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Terraform and provider versions
├── terraform.tfvars.example   # Example variable values
├── README.md                  # This file
└── modules/
    ├── security/              # Security group module
    │   ├── security_groups.tf
    │   ├── nacls.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── endpoints/             # VPC endpoints module
        ├── vpc_endpoints.tf
        ├── zone_associations.tf
        ├── variables.tf
        └── outputs.tf
```

## Additional Resources

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Sharing VPC Endpoints with AWS PrivateLink](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/centralized-access-to-vpc-private-endpoints.html)
- [VPC Peering Best Practices](https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-basics.html)
- [Route53 Private Hosted Zones](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html)

