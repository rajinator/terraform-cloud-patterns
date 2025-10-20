# Using Terraform Workspaces for Multiple Clusters/Environments

This configuration supports Terraform workspaces, allowing you to create and manage multiple EKS clusters or environments from the same code.

## What are Terraform Workspaces?

Workspaces allow you to manage multiple states of the same infrastructure. Each workspace has its own state file, letting you create isolated environments like `dev`, `staging`, `production`, or even separate clusters for different teams or applications.

## Workspace-Based Naming

By default, the cluster name is set to `eks-{workspace}`:
- `default` workspace → `eks-default`
- `dev` workspace → `eks-dev`
- `production` workspace → `eks-production`
- `app-team` workspace → `eks-app-team`

You can override this by setting `cluster_name` variable.

## Use Cases

### 1. Multiple Environments

Create separate clusters for different environments:

```bash
# Development environment
terraform workspace new dev
terraform apply -var-file="dev.tfvars"

# Production environment
terraform workspace new production
terraform apply -var-file="production.tfvars"
```

### 2. Team/Application-Specific Clusters

Create dedicated clusters for different teams or applications:

```bash
# ML team cluster
terraform workspace new ml-workloads
terraform apply -var="cluster_name=ml-cluster"

# API services cluster
terraform workspace new api-services
terraform apply -var="cluster_name=api-cluster"
```

### 3. CI/CD Clusters

Create clusters optimized for CI/CD workloads:

```bash
terraform workspace new cicd
terraform apply -var-file="cicd.tfvars"
```

**Example `cicd.tfvars`:**
```hcl
cluster_name = "cicd-cluster"
vpc_id       = "vpc-cicd123"

# More spot instances for cost savings
# Modify node groups in eks_cluster.tf to emphasize spot workers
```

## Workflow

### Creating a New Environment

```bash
# 1. Create workspace
terraform workspace new staging

# 2. Create environment-specific tfvars
cat > staging.tfvars <<EOF
vpc_id             = "vpc-staging123"
private_subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]
private_vpc_rtbs   = ["rtb-staging"]
private_vpc_nacl_id = "acl-staging"
vpn_endpoint_cidr  = "10.60.0.0/22"
peered_vpc_cidrs   = ["10.20.0.0/16"]
eks_creation_phase = "false"
EOF

# 3. Apply configuration
terraform init  # First time only
terraform apply -var-file="staging.tfvars"
```

### Switching Between Workspaces

```bash
# List workspaces
terraform workspace list

# Switch to a workspace
terraform workspace select production

# Show current workspace
terraform workspace show
```

### Managing Separate Clusters

```bash
# Work on dev cluster
terraform workspace select dev
kubectl config use-context eks-dev
terraform apply

# Switch to prod cluster
terraform workspace select production  
kubectl config use-context eks-production
terraform plan
```

## Best Practices

### 1. Use Separate tfvars Files

Create environment-specific variable files:

```
terraform.tfvars.example  # Template
dev.tfvars               # Development
staging.tfvars           # Staging
production.tfvars        # Production
```

### 2. Environment-Specific Node Groups

You can customize node groups per environment by using workspace conditionals:

```hcl
eks_managed_node_groups = {
  general = {
    min_size     = terraform.workspace == "production" ? 3 : 1
    max_size     = terraform.workspace == "production" ? 10 : 5
    desired_size = terraform.workspace == "production" ? 3 : 1
    instance_types = terraform.workspace == "production" ? ["m5.xlarge"] : ["t3.medium"]
  }
}
```

### 3. Tagging for Visibility

The configuration automatically tags resources with the workspace name:

```hcl
tags = {
  Environment = terraform.workspace
  ManagedBy   = "Terraform"
  Workspace   = terraform.workspace
}
```

### 4. Backend Configuration

Use workspace-aware backend keys:

```hcl
backend "s3" {
  bucket = "my-terraform-state"
  key    = "eks/terraform.tfstate"  # Workspace is automatically appended
  region = "us-east-1"
}
```

State files are stored as:
- `eks/terraform.tfstate` (default workspace)
- `eks/env:/dev/terraform.tfstate` (dev workspace)
- `eks/env:/production/terraform.tfstate` (production workspace)

## Example: Three-Tier Setup

### Development Cluster
```bash
terraform workspace new dev
terraform apply \
  -var="cluster_name=dev-cluster" \
  -var="vpc_id=vpc-dev" \
  -var-file="dev.tfvars"
```

### Staging Cluster  
```bash
terraform workspace new staging
terraform apply \
  -var="cluster_name=staging-cluster" \
  -var="vpc_id=vpc-staging" \
  -var-file="staging.tfvars"
```

### Production Cluster
```bash
terraform workspace new production
terraform apply \
  -var="cluster_name=production-cluster" \
  -var="vpc_id=vpc-production" \
  -var-file="production.tfvars"
```

## Destroying a Cluster

```bash
# Switch to the workspace
terraform workspace select dev

# Destroy resources
terraform destroy -var-file="dev.tfvars"

# Delete the workspace (after resources are destroyed)
terraform workspace select default
terraform workspace delete dev
```

## Advanced: Per-Workspace Customization

You can add workspace-specific logic in `eks_cluster.tf`:

```hcl
locals {
  # Workspace-specific configurations
  workspace_config = {
    dev = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      max_size       = 3
    }
    production = {
      instance_types = ["m5.xlarge"]
      desired_size   = 3
      max_size       = 10
    }
  }
  
  # Get config for current workspace, default to dev settings
  current_config = lookup(local.workspace_config, terraform.workspace, local.workspace_config["dev"])
}
```

## Common Patterns

### Pattern 1: Shared VPC, Multiple Clusters
Multiple workspaces in the same VPC for different applications:
- `eks-api-team`
- `eks-ml-team`
- `eks-batch-jobs`

### Pattern 2: Environment Progression
Standard environment pipeline:
- `dev` → `staging` → `production`

### Pattern 3: Feature Clusters
Temporary clusters for testing:
- `feature-new-auth`
- `feature-payment-v2`

## Troubleshooting

### Wrong workspace selected
```bash
# Check current workspace
terraform workspace show

# Switch to correct one
terraform workspace select production
```

### State file conflicts
Each workspace has its own state - they don't conflict. However, AWS resources must have unique names if in the same account/region.

### Accidental deletion
Workspaces don't protect against `terraform destroy`. Use:
- AWS resource tags for cost tracking
- State file versioning in S3
- Require approval for production changes

