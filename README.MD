# Terraform Examples

Welcome to the Terraform Examples repository. This collection provides practical, real-world examples of using Terraform to provision and manage cloud infrastructure and services, derived from production use-cases that I have worked on.

Each example is self-contained in its own directory and includes a detailed `README.md` file explaining its purpose, prerequisites, and how to use it.

## Guiding Principles

The examples in this repository adhere to the following principles:
- **Infrastructure as Code (IaC):** All infrastructure is defined declaratively.
- **Modularity and Reusability:** Examples are structured to be reusable and easy to understand.
- **Security:** Based on the principle of least privilege and avoid hard-coding sensitive data.
- **Scalability:** Solutions are designed to be scalable and adaptable to different environments.

## Available Examples

| Example | Description |
| :--- | :--- |
| [**Centralized VPC Endpoints with Peering**](./vpc-endpoints-centralized-peering/) | Create centralized **VPC endpoints** in a **shared services VPC** and share them across multiple **spoke VPCs** in a **multi-account** architecture using **VPC peering** and **Route53 private hosted zones** for cost-effective, scalable **private** AWS service connectivity. |
| [**Private EKS Cluster with VPC Endpoints**](./private-eks-clusters/) | Deploy a fully **private EKS cluster** with no internet gateway using **VPC interface endpoints** for AWS API access, **modern access entry API**, **IRSA** for pod-level permissions, and secure **VPN/bastion access** patterns. |
| [**KEDA SQS Autoscaling with Pod-Level IRSA**](./keda-sqs-app-irsa/) | Demonstrates how to configure **pod-level IAM Roles for Service Accounts (IRSA)** for **Kubernetes application pods** that are autoscaled by **KEDA** based on **AWS SQS** queue depth, allowing granular IAM permissions per application. |
| *... more examples to come ...* | |

## How to Use an Example

1.  Navigate to the directory of the example you are interested in.
2.  Follow the instructions in that example's local `README.md` file.

---
*This README is designed to be a living document. As new examples are added, I will update the "Available Examples" table accordingly.*
