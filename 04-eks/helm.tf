# ==============================================================================
# Helm Provider referencing Kubernetes configuration
# ------------------------------------------------------------------------------
# Configures the Helm provider to interact with the EKS cluster using data
# from the Kubernetes API endpoint, CA certificate, and authentication token.
# ==============================================================================
provider "helm" {
  kubernetes = {
    host = aws_eks_cluster.rstudio_eks.endpoint
    cluster_ca_certificate = base64decode(
      aws_eks_cluster.rstudio_eks.certificate_authority[0].data
    )
    token = data.aws_eks_cluster_auth.rstudio_eks.token
  }
}

# ==============================================================================
# AWS EKS Cluster Authentication
# ------------------------------------------------------------------------------
# Retrieves a temporary authentication token from AWS to allow Terraform to
# interact securely with the EKS cluster using IAM permissions.
# ==============================================================================
data "aws_eks_cluster_auth" "rstudio_eks" {
  name = aws_eks_cluster.rstudio_eks.name
}

# ==============================================================================
# AWS Load Balancer Controller (Helm)
# ------------------------------------------------------------------------------
# Deploys the AWS Load Balancer Controller Helm chart, which manages ALB/NLB
# resources based on Kubernetes Ingress and Service definitions.
# ==============================================================================
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"     # Helm release name
  repository = "https://aws.github.io/eks-charts" # Official AWS chart repo
  chart      = "aws-load-balancer-controller"     # Chart to deploy
  namespace  = "kube-system"                      # Standard namespace for controllers

  values = [
    templatefile("${path.module}/yaml/aws-load-balancer.yaml.tmpl", {
      cluster_name = aws_eks_cluster.rstudio_eks.name # Pass cluster name
      role_arn     = module.load_balancer_controller_irsa.iam_role_arn
    })
  ]

  # Custom values template injects cluster name and IAM role into Helm config
}

# ==============================================================================
# Cluster Autoscaler (Helm)
# ------------------------------------------------------------------------------
# Deploys the Kubernetes Cluster Autoscaler Helm chart to monitor resource
# usage and automatically scale node groups in the EKS cluster.
# ==============================================================================
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"                      # Helm release name
  repository = "https://kubernetes.github.io/autoscaler" # Chart repo
  chart      = "cluster-autoscaler"                      # Chart name
  namespace  = "kube-system"                             # Deploy to kube-system namespace
  version    = "9.29.1"                                  # Specific version for reproducibility

  values = [
    templatefile("${path.module}/yaml/autoscaler.yaml.tmpl", {
      cluster_name = aws_eks_cluster.rstudio_eks.name
    })
  ]

  depends_on = [
    kubernetes_service_account.cluster_autoscaler
  ]
}

# ==============================================================================
# NGINX Ingress Controller (Helm)
# ------------------------------------------------------------------------------
# Deploys the NGINX Ingress Controller to manage HTTP/HTTPS routing for
# Kubernetes services exposed externally.
# ==============================================================================
# resource "helm_release" "nginx_ingress" {
#   depends_on = [helm_release.aws_load_balancer_controller]

#   name             = "nginx-ingress"                              # Helm release name
#   namespace        = "ingress-nginx"                              # Isolated namespace for ingress
#   repository       = "https://kubernetes.github.io/ingress-nginx" # Chart repo
#   chart            = "ingress-nginx"                              # Chart name
#   create_namespace = true                                         # Create namespace if missing

#   values = [
#     file("${path.module}/yaml/nginx-values.yaml")
#   ]
# }

# ==============================================================================
# AWS EFS CSI Driver (Helm)
# ------------------------------------------------------------------------------
# Enables persistent storage provisioning using Amazon EFS.
# Installs the official AWS EFS CSI driver chart into kube-system.
# ==============================================================================

resource "helm_release" "aws_efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"

  # You can omit version to always get latest, or pin a known-good one
  # version = "2.5.0"   # example known-good version
  namespace = "kube-system"

  values = [
    yamlencode({
      controller = {
        serviceAccount = {
          create = true
          name   = "efs-csi-controller-sa"
        }
      }
    })
  ]

  depends_on = [
    aws_eks_cluster.rstudio_eks
  ]
}

# ==============================================================================
# DATA SOURCE: Existing EFS File System (lookup by tag)
# ------------------------------------------------------------------------------
# Retrieves the EFS file system ID for "mcloud-efs" so it can be
# referenced by the EFS CSI driver, StorageClass, etc.
# ==============================================================================
data "aws_efs_file_system" "efs" {
  tags = {
    Name = "mcloud-efs"
  }
}


# StorageClass for dynamic EFS access points
resource "kubernetes_storage_class" "efs_sc" {

  provider = kubernetes.eks

  metadata {
    name = "efs-sc"

    # Make it the default SC:
     annotations = {
       "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "efs.csi.aws.com"

  # Optional but recommended for EFS
  mount_options = ["tls"]

  reclaim_policy      = "Retain"           # or "Delete" if you want APs cleaned up
  volume_binding_mode = "Immediate"        # EFS is network storage; immediate is fine
  allow_volume_expansion = true

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = data.aws_efs_file_system.efs.id
    directoryPerms   = "700"
    # basePath      = "/k8s"               # optional: create APs under this path
    # gidRangeStart = "1000"               # optional: see EFS CSI docs
    # gidRangeEnd   = "2000"
  }

  # If you installed the EFS CSI Driver via Helm in this run, add an explicit dependency:
  depends_on = [helm_release.aws_efs_csi_driver]
}
