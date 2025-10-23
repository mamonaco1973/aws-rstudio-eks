# ==========================================================================================
# Packer Build: RStudio AMI on Ubuntu 24.04 (Noble)
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Uses Packer to build a custom Amazon Machine Image (AMI) for RStudio Server
#   - Starts from the official Canonical Ubuntu 24.04 AMI
#   - Installs prerequisites (SSM agent, AWS CLI, packages, RStudio Server)
#   - Produces a tagged, timestamped AMI for later use in Terraform or EC2 launches
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# Packer Plugin Configuration
# - Defines the Amazon plugin required to interact with AWS
# ------------------------------------------------------------------------------------------
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon" # Official HashiCorp Amazon plugin
      version = "~> 1"                        # Any compatible version within major version 1
    }
  }
}


# ------------------------------------------------------------------------------------------
# Data Source: Base Ubuntu 24.04 AMI
# - Fetches the latest Canonical-owned AMI for Ubuntu Noble (24.04)
# - Filters to use HVM virtualization and EBS-backed storage
# ------------------------------------------------------------------------------------------
data "amazon-ami" "ubuntu_2404" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical’s AWS account ID
}


# ------------------------------------------------------------------------------------------
# Variables: Build-Time Inputs
# - Control region, instance type, networking, and subnet placement
# ------------------------------------------------------------------------------------------
variable "region" {
  default = "us-east-1" # Default AWS region
}

variable "instance_type" {
  default = "m5.large"  # Use a slightly larger instance so packer builds 
                        # will run quicker.
}

variable "vpc_id" {
  description = "The ID of the VPC to use" # Supplied by user or pipeline
  default     = ""
}

variable "subnet_id" {
  description = "The ID of the subnet to use" # Supplied by user or pipeline
  default     = ""
}


# ------------------------------------------------------------------------------------------
# Amazon-EBS Source Block
# - Launches a temporary EC2 instance from the base Ubuntu AMI
# - Provisions software and configuration
# - Creates a reusable AMI with a timestamp-based name
# ------------------------------------------------------------------------------------------
source "amazon-ebs" "rstudio_ami" {
  region        = var.region                       # AWS region
  instance_type = var.instance_type                # EC2 instance type
  source_ami    = data.amazon-ami.ubuntu_2404.id   # Base Ubuntu 24.04 AMI
  ssh_username  = "ubuntu"                         # Default SSH user for Ubuntu
  ami_name      = "rstudio_ami_${replace(timestamp(), ":", "-")}" # Timestamped AMI name
  ssh_interface = "public_ip"                      # Use public IP for provisioning
  vpc_id        = var.vpc_id                       # Target VPC
  subnet_id     = var.subnet_id                    # Target Subnet (must allow outbound internet)

  # Root EBS Volume Configuration
  launch_block_device_mappings {
    device_name           = "/dev/sda1" # Root device
    volume_size           = "16"        # Root volume size in GiB
    volume_type           = "gp3"       # gp3: cost-effective SSD
    delete_on_termination = "true"      # Cleanup volume when instance terminates
  }

  tags = {
    Name = "rstudio_ami_${replace(timestamp(), ":", "-")}" # Tag AMI with unique name
  }
}


# ------------------------------------------------------------------------------------------
# Build Block: Provisioning Scripts
# - Executes setup scripts inside the temporary EC2 instance
# - Each script installs a specific set of software or config
# ------------------------------------------------------------------------------------------
build {
  sources = ["source.amazon-ebs.rstudio_ami"]

  # Install SSM agent for AWS Systems Manager integration
  provisioner "shell" {
    script          = "./ssm.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install base packages and dependencies
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install AWS CLI tools
  provisioner "shell" {
    script          = "./awscli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install and configure RStudio Server
  provisioner "shell" {
    script          = "./rstudio.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
