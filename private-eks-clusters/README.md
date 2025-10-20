# Private EKS Cluster with VPC Endpoints

This Terraform configuration creates a fully private Amazon EKS cluster that accesses AWS services through VPC endpoints, eliminating the need for NAT gateways or internet gateways for AWS API calls.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Configuration](#configuration)
- [Cluster Access](#cluster-access)
- [Installing Cluster Components](#installing-cluster-components)
- [Outputs](#outputs)

## Overview

In production environments, running EKS clusters in fully private subnets enhances security by preventing direct internet access. This configuration demonstrates how to:

1. Deploy a private EKS cluster with no public endpoint access (configurable during creation)
2. Use VPC interface endpoints for AWS service access
3. Configure proper security groups and NACLs for endpoint traffic
4. Set up IAM Roles for Service Accounts (IRSA) for pod-level permissions
5. Use the modern EKS Access Entry API for cluster authentication

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Private VPC                         │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           VPC Interface Endpoints (from module)       │  │
│  │  • EC2  • ECR  • ELB  • Logs  • STS  • S3             │  │
│  │  • RDS  • ElastiCache  • Autoscaling                  │  │
│  └─────────────────────┬─────────────────────────────────┘  │
│                        │                                    │
│  ┌─────────────────────▼──────────────────────────────────┐ │
│  │          EKS Control Plane (Private API)               │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │         EKS Managed Node Groups                  │  │ │
│  │  │  • Pods use IRSA for AWS permissions             │  │ │
│  │  │  • All AWS API calls via VPC endpoints           │  │ │
│  │  │  • No internet gateway required                  │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  Access via: VPN or Bastion Host                            │
└─────────────────────────────────────────────────────────────┘
```

## Features

### Private Cluster Configuration
- **Fully private EKS API**: No public endpoint (configurable for initial setup)
- **Private node communication**: All traffic stays within VPC
- **VPN/Bastion access**: Secure access through private network

### Multi-Environment Support
- **Terraform Workspaces**: Create multiple clusters (dev, staging, prod) or purpose-specific clusters (CI/CD, ML, APIs)
- **Flexible naming**: Automatic workspace-based naming or custom cluster names
- **Environment tagging**: Automatic tagging based on workspace for cost tracking

### VPC Endpoints Integration
- **Flexible deployment**: Create local VPC endpoints OR use centralized endpoints from another VPC
- **Modular endpoint management**: Uses dedicated modules for endpoints and security
- **Required endpoints**: EC2, ECR (API & Docker), ELB, Logs, STS, S3
- **Optional endpoints**: RDS, ElastiCache, Autoscaling, and more
- **Route53 integration**: Supports peering with centralized VPC endpoints
- **Cost optimization**: Use centralized endpoints to share costs across multiple clusters

### Modern Authentication
- **EKS Access Entries**: Uses the latest access entry API (not aws-auth ConfigMap)
- **Cluster access policies**: Fine-grained permissions with AWS-managed policies
- **IRSA support**: Pod-level IAM permissions via service accounts

### Security Features
- **Security groups**: Dedicated SG for VPC endpoints with least privilege
- **Network ACLs**: Additional network layer controls
- **Pod security**: IRSA for workload identity
- **Encryption**: KMS encryption for EKS secrets

### Cluster Add-ons
- **AWS EBS CSI Driver**: Persistent volume support
- **CoreDNS**: DNS resolution
- **kube-proxy**: Network proxy
- **VPC CNI**: Pod networking

## Prerequisites

Before using this configuration, ensure you have:

1. **Existing VPC** with:
   - Private subnets across multiple availability zones
   - Route tables configured
   - Network ACL

2. **VPN or Bastion Host**:
   - For accessing the private EKS API endpoint
   - VPN CIDR or bastion security group for cluster access

3. **Terraform**:
   - Version >= 1.5
   - AWS provider ~> 5.0

4. **AWS Credentials**:
   - IAM permissions to create EKS clusters, VPC endpoints, IAM roles

5. **Optional - Centralized VPC Endpoints**:
   - If using Route53 zone association with a hub VPC
   - Zone IDs from the centralized endpoints

## Usage

### 1. Configure Variables

Copy the example file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# VPC and networking
vpc_id             = "vpc-your-id"
private_subnet_ids = ["subnet-id-1", "subnet-id-2", "subnet-id-3"]
private_vpc_rtbs   = ["rtb-your-id"]
private_vpc_nacl_id = "acl-your-id"

# VPN access
vpn_endpoint_cidr = "10.50.0.0/22"

# For first-time cluster creation, enable temporary public access
eks_creation_phase              = "true"
eks_creation_public_access_ip   = ["your-public-ip/32"]
```

### 2. Initial Cluster Creation

For the **first deployment**, enable public API access temporarily:

```hcl
eks_creation_phase            = "true"
eks_creation_public_access_ip = ["your-ip/32"]
```

```bash
terraform init
terraform plan
terraform apply
```

### 3. Secure the Cluster

After cluster is created and configured, make it fully private:

```hcl
eks_creation_phase = "false"
```

```bash
terraform apply
```

### 4. Get Cluster Access

Update your kubeconfig:

```bash
aws eks update-kubeconfig --region us-east-1 --name my-private-eks
```

Ensure you're connected via VPN or bastion host to reach the private endpoint.

## Configuration

### Main Configuration Files

- **`eks_cluster.tf`**: EKS cluster definition with flexible node groups
- **`irsa_cluster_autoscaler.tf`**: IRSA setup for cluster autoscaler
- **`variables.tf`**: Input variable definitions
- **`terraform.tfvars.example`**: Example values (copy to create environment-specific files)
- **`outputs.tf`**: Output definitions
- **`versions.tf`**: Provider version constraints
- **`WORKSPACES.md`**: Guide for using Terraform workspaces for multiple clusters/environments

### Module Structure

```
.
├── eks_cluster.tf                    # Main EKS cluster configuration
├── irsa_cluster_autoscaler.tf        # IRSA for cluster autoscaler
├── outputs.tf                        # Terraform outputs
├── variables.tf                      # Input variables
├── versions.tf                       # Provider versions
├── terraform.tfvars.example          # Example configuration
├── cluster-autoscaler-values.yaml.example  # Helm values for autoscaler
├── rbac-jenkins.yaml.example         # Optional: Example Jenkins RBAC
├── WORKSPACES.md                     # Workspace usage guide
├── vpc_networking.tf                 # VPC, security, and endpoints (conditional)
└── modules/
    ├── endpoints/                    # VPC endpoints module (optional)
    │   ├── vpc_endpoints.tf
    │   └── variables.tf
    └── security/                     # Security groups and NACLs
        ├── security_groups.tf
        ├── nacls.tf
        ├── outputs.tf
        └── variables.tf
```

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | EKS cluster name (optional, defaults to `eks-{workspace}`) | `"my-cluster"` or `""` |
| `create_vpc_endpoints` | Create local VPC endpoints or use centralized endpoints | `true` or `false` |
| `vpc_id` | VPC ID where EKS will be deployed | `vpc-0123456789abcdef0` |
| `private_subnet_ids` | Private subnets for nodes and endpoints | `["subnet-abc", "subnet-def"]` |
| `vpn_endpoint_cidr` | VPN CIDR for API access | `10.200.0.0/22` |
| `peered_vpc_cidrs` | List of peered VPC CIDRs for API access | `["10.20.0.0/16", "10.30.0.0/16"]` |
| `eks_creation_phase` | Enable temporary public access for debugging | `true` or `false` |
| `peering_zone_ids` | Route53 zone IDs (required if using centralized endpoints) | See example file |

### EKS Access Configuration

This example uses the **modern EKS Access Entry API** instead of the legacy aws-auth ConfigMap.

**Simple approach:** Just provide a list of IAM role/user ARNs:

```hcl
# terraform.tfvars
cluster_admin_arns = [
  "arn:aws:iam::123456789012:role/MyAdminRole",
  "arn:aws:iam::123456789012:role/DevOpsTeam"
]
```

All ARNs in the list automatically receive cluster admin access. No complex configuration needed!

**Available AWS managed policies:**
- `AmazonEKSClusterAdminPolicy` - Full cluster admin (default)
- `AmazonEKSAdminPolicy` - Admin without system namespaces
- `AmazonEKSEditPolicy` - Edit resources
- `AmazonEKSViewPolicy` - Read-only access

**For more granular permissions:** Edit the `access_entries` block in `eks_cluster.tf` directly to add different permission levels.

## Using Terraform Workspaces

This configuration supports **Terraform workspaces** for managing multiple clusters. See [`WORKSPACES.md`](./WORKSPACES.md) for detailed examples.

### Quick Start with Workspaces

```bash
# Create a development cluster
terraform workspace new dev
terraform apply -var-file="dev.tfvars"

# Create a production cluster  
terraform workspace new production
terraform apply -var-file="production.tfvars"

# List all clusters
terraform workspace list

# Switch between clusters
terraform workspace select dev
```

## Cluster Access

### Option 1: Via VPN

1. Connect to your VPN
2. Update kubeconfig:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name my-private-eks
   ```
3. Verify access:
   ```bash
   kubectl get nodes
   ```

### Option 2: Via Bastion/Jump Host

1. SSH to bastion in the VPC
2. Install kubectl and AWS CLI
3. Configure credentials
4. Update kubeconfig and access cluster

## Installing Cluster Components

### Cluster Autoscaler

1. Update the values file:
   ```bash
   cp cluster-autoscaler-values.yaml.example cluster-autoscaler-values.yaml
   # Edit the file with your cluster name
   ```

2. Install via Helm:
   ```bash
   helm repo add autoscaler https://kubernetes.github.io/autoscaler
   helm install cluster-autoscaler autoscaler/cluster-autoscaler \
     --namespace kube-system \
     --values cluster-autoscaler-values.yaml
   ```

The IRSA role is automatically created by `irsa_cluster_autoscaler.tf`.

### Other Components

Install additional components as needed:
- **Metrics Server**: For HPA
- **AWS Load Balancer Controller**: For ALB/NLB via IRSA
- **External DNS**: For Route53 integration
- **Cert Manager**: For certificate management

## Outputs

The configuration outputs useful information:

```hcl
# Cluster information
cluster_id                = "my-private-eks"
cluster_endpoint          = "https://ABC123.gr7.us-east-1.eks.amazonaws.com"
cluster_security_group_id = "sg-..."

# OIDC provider for IRSA
cluster_oidc_issuer_url   = "https://oidc.eks.us-east-1.amazonaws.com/id/ABC123..."

# VPC endpoints
vpc_endpoint_ids          = { ec2 = "vpce-...", ... }

# Node group information
node_groups               = { ... }
```

## Advanced Configuration

### Node Group Overview

The configuration includes three pre-configured node groups suitable for different workloads:

1. **`general-purpose-1`**: 
   - **Purpose**: Standard application workloads
   - **Instances**: ON_DEMAND t3.large/t3a.large
   - **Use cases**: Web apps, APIs, general services

2. **`large-stateful-1`**:
   - **Purpose**: Memory-intensive or stateful workloads  
   - **Instances**: t3a.large with taints
   - **Use cases**: Databases, caches, stateful applications
   - **Taint**: `large-stateful-node=true:NO_SCHEDULE` (only pods with tolerations scheduled)

3. **`spot-workers`**:
   - **Purpose**: Cost-optimized workloads, batch processing
   - **Instances**: SPOT instances (t3/m5 families)
   - **Use cases**: CI/CD, batch jobs, non-critical workloads, dev/test
   - **Note**: Can be interrupted by AWS

### Customizing Node Groups

Edit `eks_cluster.tf` to add or modify node groups:

```hcl
eks_managed_node_groups = {
  my-custom-nodegroup = {
    min_size       = 2
    max_size       = 10
    desired_size   = 3
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"  # or "SPOT"
    
    labels = merge(
      local.common_tags,
      {
        NodeType = "custom"
        Team     = "platform"
      }
    )
    
    # Optional: Taints for workload isolation
    # taints = [{
    #   key    = "dedicated"
    #   value  = "ml-workload"
    #   effect = "NO_SCHEDULE"
    # }]
  }
}
```

### Node Group Strategies by Use Case

**Development/Testing:**
```hcl
# Use spot instances, lower capacity
min_size  = 1
max_size  = 3
capacity_type = "SPOT"
```

**Production:**
```hcl
# Use on-demand, higher availability
min_size  = 3
max_size  = 10
capacity_type = "ON_DEMAND"
```

**CI/CD:**
```hcl
# Spot instances, scale from zero
min_size  = 0
max_size  = 10
capacity_type = "SPOT"
# Let cluster autoscaler scale based on pod demand
```

**ML/Data Processing:**
```hcl
# GPU or compute-optimized instances
instance_types = ["g4dn.xlarge", "p3.2xlarge"]
taints = [{
  key    = "nvidia.com/gpu"
  value  = "true"
  effect = "NO_SCHEDULE"
}]
```

### VPC Endpoints: Local vs Centralized

This configuration supports two deployment patterns:

#### Option 1: Local VPC Endpoints (Default)

Create VPC endpoints directly in the cluster VPC:

```hcl
create_vpc_endpoints = true
```

**Pros:**
- Simple setup
- No VPC peering required
- Direct control over endpoints

**Cons:**
- Higher cost (per-cluster endpoints)
- More resources to manage

#### Option 2: Centralized VPC Endpoints

Use shared VPC endpoints from a centralized hub VPC:

```hcl
create_vpc_endpoints = false
```

**Prerequisites:**
1. Deploy centralized VPC endpoints in a hub VPC (see `vpc-endpoints-centralized-peering` example)
2. Set up VPC peering between hub and cluster VPCs
3. Configure route tables for peering traffic
4. Get Route53 zone IDs from centralized endpoints
5. Associate cluster VPC with the hosted zones (from spoke account)

**Pros:**
- **Cost savings**: Share endpoints across multiple clusters
- Centralized management
- Simplified networking for multi-cluster setups

**Cons:**
- Requires VPC peering setup
- More complex initial configuration
- Cross-VPC dependency

**Example configuration for centralized endpoints:**

```hcl
# terraform.tfvars
create_vpc_endpoints = false

# Zone IDs from your centralized VPC endpoints module
peering_zone_ids = {
  "ec2"        = "Z01234567890ABCDEFGHI"  # From hub VPC outputs
  "ecr-api"    = "Z01234567890ABCDEFGHI"
  "ecr-dkr"    = "Z01234567890ABCDEFGHI"
  # ... other endpoints
}
```

### Adding VPC Endpoints (Local Mode)

When `create_vpc_endpoints = true`, you can add more AWS service endpoints by editing `modules/endpoints/vpc_endpoints.tf`

## Security Best Practices

1. **Keep cluster fully private** after initial setup
2. **Use IRSA** for all pod AWS permissions (not instance profiles)
3. **Enable audit logging** for compliance
4. **Restrict VPC endpoint access** to necessary CIDR blocks only
5. **Use KMS encryption** for secrets at rest
6. **Regular updates**: Keep EKS version and add-ons current
7. **Network policies**: Implement pod-to-pod network policies

## Troubleshooting

### Can't connect to cluster

- Verify VPN connection or bastion access
- Check security group rules allow your CIDR on port 443
- Ensure cluster endpoint is private-only after securing

### Pods can't pull images from ECR

- Verify ECR endpoints (ecr.api and ecr.dkr) are created
- Check security groups allow HTTPS from pod CIDR
- Verify DNS resolution inside pods

### Cluster autoscaler not working

- Check IRSA role is created and annotated
- Verify service account has correct annotations
- Check autoscaler logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler`

## Cost Optimization

- **EC2 Instances**: Based on node instance types
- **Consider**: Spot instances for non-critical workloads

## Additional Resources

- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)

