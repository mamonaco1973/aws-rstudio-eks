# AWS Elastic Container Registry (ECR) for storing Docker container images
# Stores rstudio containers

resource "aws_ecr_repository" "rstudio" {
  name                 = "rstudio"                # ECR repository name
  image_tag_mutability = "MUTABLE"                # Allow overwriting of image tags

  # Enable automatic image scanning for vulnerabilities
  image_scanning_configuration {
    scan_on_push = true                           # Scan images on push
  }
}


