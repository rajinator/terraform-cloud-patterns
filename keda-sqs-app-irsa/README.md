# Terraform for KEDA SQS Autoscaling with Pod-Level IRSA

This terraform example provides a scalable and secure configuration to manage AWS IAM Roles for Service Accounts (IRSA) at the **pod level** for Kubernetes applications. These applications are autoscaled by [KEDA](https://keda.sh/) based on the depth of an AWS SQS queue.

**Key Distinction:** The IRSA configuration applies to the **application pods themselves**, not the KEDA operator. This allows each application to have its own granular IAM permissions, following the principle of least privilege by creating a dedicated IAM role for each application. KEDA uses the pod's identity (`identityOwner: pod`) to authenticate with AWS SQS for scaling decisions.

## Features

-   **Scalable:** Easily manage IAM roles for any number of applications by editing a single map.
-   **Secure:** Enforces the principle of least privilege by creating a separate, narrowly-scoped IAM role for each application.
-   **Reusable Module:** The core logic is encapsulated in a reusable Terraform module.
-   **Declarative:** Define your applications and their required permissions in a simple, declarative map.

## Prerequisites

-   Terraform v1.x
-   An existing Amazon EKS Cluster.
-   The EKS cluster must have an [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) configured.
-   [KEDA](https://keda.sh/) installed in the cluster.
-   AWS credentials configured for Terraform.

## Configuration

### Project Structure

```
.
├── apps.tf             # Instantiates the IRSA module for each application
├── locals.tf           # Main configuration file to define applications
├── modules/
│   └── irsa/           # Reusable module to create a single IAM role
├── outputs.tf          # Declares project-level outputs
├── terraform.tfvars    # (User-created) To provide input variables
├── variables.tf        # Defines input variables for the project
└── versions.tf         # Defines provider versions
```

### 1. Define Your Applications

To add, remove, or modify an application, copy `locals.tf.example` as `locals.tf` and edit the `applications` map in `locals.tf`. The key of the map (e.g., `app-a`) is used as a unique identifier for the application.

**Example: `locals.tf`**

```terraform
locals {
  applications = {
    app-a = {
      namespace       = "default"
      service_account = "app-a-sa"
      sqs_queue_arn   = "arn:aws:sqs:us-east-1:123456789012:app-a-queue"
    },
    app-b = {
      namespace       = "default"
      service_account = "app-b-sa"
      sqs_queue_arn   = "arn:aws:sqs:us-east-1:123456789012:app-b-queue"
    },
  }
}
```

### 2. Provide Input Variables

Create a `terraform.tfvars` file and provide the OIDC provider URL for your EKS cluster.

**Example: `terraform.tfvars`**

```hcl
oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
```

## Applying the Configuration

1.  Initialize Terraform:
    ```sh
    terraform init
    ```
2.  Plan the changes:
    ```sh
    terraform plan
    ```
3.  Apply the changes:
    ```sh
    terraform apply
    ```

### Using Terraform Workspaces for Multiple Environments

[Terraform Workspaces](https://www.terraform.io/language/state/workspaces) allow you to manage multiple independent states of the same configuration. This is useful for creating separate environments like `dev`, `staging`, and `production` without duplicating your code.

Each workspace has its own state file, which means you can deploy different versions or configurations of your resources to each environment.

**Workflow:**

1.  **Create a new workspace:**
    ```sh
    # Create a 'dev' environment
    terraform workspace new dev

    # Create a 'prod' environment
    terraform workspace new prod
    ```

2.  **List available workspaces:**
    ```sh
    terraform workspace list
    ```
    You will see `default`, `dev`, and `prod`. The one with the `*` is currently active.

3.  **Select a workspace:**
    Before running `plan` or `apply`, select the workspace you want to modify.
    ```sh
    terraform workspace select dev
    ```

4.  **Apply the configuration:**
    Now, when you run `terraform apply`, the resources will be created and managed in the `dev` state file (`terraform.tfstate.d/dev/terraform.tfstate`).

**Using Workspaces in Code:**

You can use the `terraform.workspace` variable in your code to create environment-specific configurations. For example, you could use it to name resources differently or to look up different variable maps.

**Example: Environment-specific tags or names**

In `locals.tf`, you could modify resource names to include the environment:

```terraform
resource "aws_iam_role" "this" {
  # ...
  name = "${var.app_name}-${terraform.workspace}"
}
```

**Example: Environment-specific variables**

You can also have different `.tfvars` files for each environment and load them as needed.

```sh
# For dev
terraform workspace select dev
terraform apply -var-file="dev.tfvars"

# For prod
terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```
This approach provides a clean and scalable way to manage infrastructure for multiple environments.

## Kubernetes Configuration

For each application, the corresponding Kubernetes `ServiceAccount` must be annotated with the IAM Role ARN created by Terraform. This is the crucial step that links your Kubernetes workload to the AWS IAM permissions.

The `ServiceAccount` can either be created after running Terraform or it can be created beforehand and annotated later.

### 1. Get the IAM Role ARN

First, after successfully running `terraform apply`, get the map of all created IAM role ARNs:

```sh
terraform output iam_role_arns
```

### 2. Annotate the Service Account

You now have two options to associate the IAM Role with your Service Account.

**Option A: Create a New Service Account**

If you haven't created the Service Account yet, you can create a YAML manifest and include the annotation with the ARN from the previous step.

**Example: `service-account.yaml`**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-a-sa # Must match service_account in locals.tf
  namespace: default # Must match namespace in locals.tf
  annotations:
    # The ARN from the terraform output
    eks.amazonaws.com/role-arn: "arn:aws:iam::111122223333:role/app-a-irsa"
```
Then apply it: `kubectl apply -f service-account.yaml`

**Option B: Annotate an Existing Service Account**

If your Service Account already exists in the cluster (perhaps created by a different process or as part of a Helm chart), you can apply the annotation directly using `kubectl`.

```sh
# Get the specific ARN you need from the 'terraform output' command for 'app-a'
ROLE_ARN=$(terraform output -json iam_role_arns | jq -r '.["app-a"]')

# Annotate the service account
kubectl annotate serviceaccount app-a-sa -n default \
    eks.amazonaws.com/role-arn=$ROLE_ARN \
    --overwrite
```
This approach is useful for integrating with existing deployment workflows or GitOps practices.

### 3. Configure Your Deployment and ScaledObject

-   Ensure your application's `Deployment` uses the annotated service account: `serviceAccountName: app-a-sa`.
-   Ensure your KEDA `ScaledObject` trigger uses `identityOwner: pod`. This tells KEDA to use the pod's identity (via the service account) to authenticate with AWS.

**Example: `scaled-object.yaml`**

```yaml
# ...
spec:
  triggers:
    - type: aws-sqs-queue
      metadata:
        # ...
        identityOwner: pod
```

## Module Reference (`./modules/irsa`)

### Input Variables

| Name                  | Description                                          | Type     | Default | Required |
| --------------------- | ---------------------------------------------------- | -------- | ------- | :------: |
| `app_name`            | A unique name for the application.                   | `string` | n/a     |   yes    |
| `app_namespace`       | Kubernetes namespace for the application.            | `string` | n/a     |   yes    |
| `app_service_account` | Name of the application's service account.           | `string` | n/a     |   yes    |
| `sqs_queue_arn`       | ARN of the SQS queue for the application to monitor. | `string` | n/a     |   yes    |
| `oidc_provider_url`   | OIDC provider URL for the EKS cluster.               | `string` | n/a     |   yes    |

### Outputs

| Name           | Description                       |
| -------------- | --------------------------------- |
| `iam_role_arn` | The ARN of the created IAM role.  |
