# Create an Amazon EKS Cluster
# This resource provisions an EKS cluster with a specified IAM role and VPC configuration.

resource "aws_eks_cluster" "rstudio_eks" {
  name     = "rstudio-eks-cluster"                # Define the name of the EKS cluster
  role_arn = aws_iam_role.eks_cluster_role.arn  # Attach the IAM role for EKS management

  vpc_config {
    subnet_ids = [data.aws_subnet.k8s-subnet-1.id, 
                  data.aws_subnet.k8s-subnet-2.id]  # Specify the subnets where the EKS cluster will be deployed
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]         # Ensure IAM policies are attached before creating the cluster
}

# Define a Launch Template for EKS Worker Nodes
# This template configures metadata options for security purposes

resource "aws_launch_template" "eks_worker_nodes" {
  name = "eks-worker-nodes"    # Assign a name to the launch template

  metadata_options {
    http_endpoint = "enabled"  # Enable the instance metadata service (IMDS)
    http_tokens   = "optional" # Allow IMDSv2 but do not enforce it 
  }  

  # Define tags for instances launched from this template
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "eks-worker-node-flask-api"
    }
  }
}

# Create an EKS Node Group
# This provisions worker nodes in the EKS cluster and assigns the necessary IAM role

resource "aws_eks_node_group" "rstudio_nodes" {
  cluster_name    = aws_eks_cluster.rstudio_eks.name                           # Associate the node group with the specified EKS cluster
  node_group_name = "rstudio-nodes"                                            # Define the name of the node group
  node_role_arn   = aws_iam_role.eks_node_role.arn                           # Attach the IAM role for worker nodes
  subnet_ids      = [data.aws_subnet.k8s-private-subnet-1.id,
                     data.aws_subnet.k8s-private-subnet-2.id]                # Deploy worker nodes in specified subnets

  instance_types  = ["t3.medium"]                                            # Choose the instance type for worker nodes

  # Use the previously defined launch template for worker node configuration
  launch_template {
    id      = aws_launch_template.eks_worker_nodes.id              # Reference the launch template ID
    version = aws_launch_template.eks_worker_nodes.latest_version  # Always use the latest launch template version
  }

  scaling_config {
    desired_size = 1  # Set the desired number of worker nodes (scale accordingly)
    max_size     = 4  # Maximum number of worker nodes allowed (increase for scaling needs)
    min_size     = 1  # Minimum number of worker nodes (ensure redundancy if needed)
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,  # Ensure the node IAM role has required permissions
    aws_iam_role_policy_attachment.eks_cni_policy,          # Attach policy for EKS networking (CNI)
    aws_iam_role_policy_attachment.eks_registry_policy,     # Allow worker nodes to pull images from ECR
    aws_iam_role_policy_attachment.ssm_policy               # Enable access to AWS Systems Manager for logging and monitoring
  ]

  tags = {
    "k8s.io/cluster-autoscaler/enabled"                    = "true"
    "k8s.io/cluster-autoscaler/flask-eks-cluster"          = "owned"
  }

  labels = {
    nodegroup = "rstudio-nodes"
  }
}


# Retrieve the TLS Certificate for EKS OIDC Provider
# This ensures secure authentication for OIDC-based IAM roles

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.rstudio_eks.identity[0].oidc[0].issuer  # Fetch the OIDC provider URL from the EKS cluster
}

# Create an OIDC Identity Provider for EKS
# This allows Kubernetes workloads to assume IAM roles using OpenID Connect

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  url = aws_eks_cluster.rstudio_eks.identity[0].oidc[0].issuer  # Set the OIDC provider URL for IAM authentication

  client_id_list = [
    "sts.amazonaws.com"  # Allow the AWS Security Token Service (STS) to assume roles on behalf of Kubernetes workloads
  ]

  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]  # Use the retrieved TLS certificate fingerprint for secure communication
}

# =============================================
# Kubernetes Provider Configuration
# =============================================
provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.rstudio_eks.endpoint                                     # Use EKS cluster API endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.rstudio_eks.certificate_authority[0].data)  # Decode CA certificate
  token                  = data.aws_eks_cluster_auth.rstudio_eks.token                              # Use token authentication for EKS API
}

resource "kubernetes_service_account" "cluster_autoscaler" {
  provider = kubernetes.eks

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
    }
  }

  depends_on = [aws_eks_cluster.rstudio_eks]
}

