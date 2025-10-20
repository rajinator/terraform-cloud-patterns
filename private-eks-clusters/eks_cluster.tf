#### Private EKS Cluster Configuration

locals {
  # Use workspace name to create different clusters or use a custom name
  cluster_name                  = var.cluster_name != "" ? var.cluster_name : "eks-${terraform.workspace}"
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
  
  # Environment-specific tags
  common_tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
    Workspace   = terraform.workspace
  }
  
  # Common IAM policies (DRY)
  ebs_csi_policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  
  # Common node group settings (DRY)
  common_node_group_config = {
    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = local.ebs_csi_policy_arn
    }
    tags = {
      "k8s.io/cluster-autoscaler/enabled"              = "true"
      "k8s.io/cluster-autoscaler/${local.cluster_name}" = "true"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

module "eks" {
  # Uncomment the below line with depends_on to add dependency on VPC endpoints if creating them locally
  # If using centralized endpoints, this dependency is not needed
  #depends_on = [module.vpc_endpoints, module.security]

  # Add dependency on security module to ensure certain security groups are created before EKS cluster is created
  depends_on = [module.security]

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name              = local.cluster_name
  cluster_version           = "1.32"  # To parameterize: use var.cluster_version
  cluster_enabled_log_types = null    # Set to ["api", "audit", "authenticator"] for logging
  
  ## Cluster addons - enabled by default
  # To parameterize: Create a variable to conditionally enable/disable addons
  cluster_addons                                 = {
    aws-ebs-csi-driver = {
      most_recent = true
      depends_on = [module.eks.eks_managed_node_groups]
    }
    coredns    = {
      most_recent = true
      depends_on = [module.eks.eks_managed_node_groups]
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni    = {
      most_recent = true
    }
  }
  cluster_endpoint_public_access                 = var.eks_creation_phase ? "true" : "false"
  cluster_endpoint_public_access_cidrs           = var.eks_creation_phase ? var.eks_creation_public_access_ip : ["127.0.0.0/8"]
  cluster_endpoint_private_access                = "true"
  
  # Private API access is controlled via cluster_security_group_additional_rules below
  subnet_ids                                     = var.private_subnet_ids
  vpc_id                                         = data.aws_vpc.selected.id
  enable_irsa                                    = true
  #cluster_enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler" ]
  #worker_ami_name_filter                         = "AL2_x86_64"

  ### Modern authentication using EKS Access Entries API
  # Simple approach: provide a list of ARNs in var.cluster_admin_arns
  # All get cluster admin access automatically
  
  access_entries = {
    for idx, arn in var.cluster_admin_arns : 
    "admin-${idx}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Cluster SG rules for private endpoint access - replaces cluster_endpoint_private_access_cidrs
  cluster_security_group_additional_rules = merge(
    # Static rules
    {
      private_api_endpoint_vpn_cidr_access = {
        description = "Private API access for VPN CIDR block"
        protocol    = "tcp"
        from_port   = 443
        to_port     = 443
        type        = "ingress"
        cidr_blocks = [var.vpn_endpoint_cidr]
      }
    },
    # Dynamic rules for peered VPC CIDRs
    {
      for idx, cidr in var.peered_vpc_cidrs :
      "peered_vpc_${idx}_api_access" => {
        description = "Private API access from peered VPC CIDR ${cidr}"
        protocol    = "tcp"
        from_port   = 443
        to_port     = 443
        type        = "ingress"
        cidr_blocks = [cidr]
      }
    }
  )

  tags = merge(
    local.common_tags,
    {
      Component = "Kubernetes"
    }
  )

  # Add to provide similar level of acces as v17.x for nodes
  node_security_group_additional_rules = {
    ingress_control_plane = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_self_all = {
      description                   = "Control plane to nodes on ephemeral ports"
      protocol                      = "tcp"
      from_port                     = 1025
      to_port                       = 65535
      type                          = "ingress"
      source_security_group_ids     = [module.eks.cluster_security_group_id]
    }
    ingress_vault_injector_webhook = {
      description                   = "Access to Vault Agent Injector webhook endpoint from API server"
      protocol                      = "tcp"
      from_port                     = 8080
      to_port                       = 8080
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    prometheus_service_from_api_server = {
      description                   = "With this rule, the API server would be allowed to reach prometheus port. With this metrics work in lens"
      protocol                      = "TCP"
      from_port                     = 9090
      to_port                       = 9090
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  # Common defaults for all node groups (DRY)
  eks_managed_node_group_defaults = {
    ami_type                     = "AL2_x86_64"
    disk_size                    = 30
    key_name                     = "eks-node-key"  # Optional: SSH key for node access
    source_security_group_ids    = [module.eks.cluster_security_group_id]
    iam_role_additional_policies = local.common_node_group_config.iam_role_additional_policies
    tags                         = local.common_node_group_config.tags
  }

  eks_managed_node_groups = {
    general-purpose-1 = {
      desired_size   = 1
      max_size       = 5
      min_size       = 1
      instance_types = ["t3a.xlarge"]
      disk_size      = 40

      labels = merge(
        local.common_tags,
        {
          NodeType = "general-purpose"
        }
      )

      lifecycle = {
        create_before_destroy = true
      }
    },
    large-stateful-1 = {
      desired_size   = 1
      max_size       = 3
      min_size       = 1
      instance_types = ["t3a.large"]

      # Taint for stateful workloads only
      taints = [
        {
          key    = "large-stateful-node"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      labels = merge(
        local.common_tags,
        {
          NodeType = "stateful"
        }
      )

      lifecycle = {
        create_before_destroy = true
      }
    },
    spot-workers = {
      desired_size   = 0
      max_size       = 5
      min_size       = 0
      instance_types = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
      capacity_type  = "SPOT"
      disk_size      = 40

      # Optional: Taint for specific workloads (e.g., batch jobs, CI/CD)
      # Uncomment to restrict to tolerant workloads:
      # taints = [{
      #   key    = "spot-instance"
      #   value  = "true"
      #   effect = "NO_SCHEDULE"
      # }]

      labels = merge(
        local.common_tags,
        {
          NodeType     = "spot"
          CapacityType = "spot"
        }
      )
    },
  }

  ## OLD auth deprecated
  # manage_aws_auth_configmap = false
  # aws_auth_roles            = var.map_roles
  # aws_auth_users            = var.map_users
  # aws_auth_accounts         = var.map_accounts
}