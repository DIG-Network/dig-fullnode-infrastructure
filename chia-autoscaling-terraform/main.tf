terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Networking module
module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  chia_port            = var.chia_port
  chia_rpc_port        = var.chia_rpc_port
  chia_farmer_port     = var.chia_farmer_port
  tags                 = var.tags
}

# Storage module
module "storage" {
  source = "./modules/storage"

  project_name          = var.project_name
  environment           = var.environment
  subnet_ids            = module.networking.private_subnet_ids
  security_group_id     = module.networking.efs_security_group_id
  efs_performance_mode  = var.efs_performance_mode
  efs_throughput_mode   = var.efs_throughput_mode
  backup_retention_days = var.backup_retention_days
  tags                  = var.tags
}

# Load balancer module
module "load_balancer" {
  source = "./modules/load-balancer"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.networking.load_balancer_security_group_id
  chia_port         = var.chia_port
  chia_rpc_port     = var.chia_rpc_port
  tags              = var.tags
}

# Prepare user data script
locals {
  user_data_vars = {
    efs_id         = module.storage.efs_id
    aws_region     = var.aws_region
    chia_port      = var.chia_port
    project_name   = var.project_name
    environment    = var.environment
  }
  
  # Render user data script with variables
  user_data_script = templatefile("${path.module}/scripts/user-data.sh", local.user_data_vars)
}

# Compute module
module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.networking.vpc_id
  subnet_ids                = module.networking.private_subnet_ids
  security_group_id         = module.networking.chia_nodes_security_group_id
  instance_profile_name     = module.storage.instance_profile_name
  instance_type             = var.instance_type
  key_pair_name             = var.key_pair_name
  ami_id                    = var.ami_id
  user_data_script          = local.user_data_script
  asg_min_size              = var.asg_min_size
  asg_max_size              = var.asg_max_size
  asg_desired_capacity      = var.asg_desired_capacity
  health_check_grace_period = var.health_check_grace_period
  scale_out_cpu_threshold   = var.scale_out_cpu_threshold
  scale_in_cpu_threshold    = var.scale_in_cpu_threshold
  target_group_arns         = module.load_balancer.target_group_arns
  enable_detailed_monitoring = var.enable_detailed_monitoring
  tags                      = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "chia_monitoring" {
  dashboard_name = "${var.project_name}-${var.environment}-chia-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            [".", ".", { stat = "Maximum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EC2 CPU Utilization"
          period  = 300
          annotations = {
            horizontal = [
              {
                label = "Scale Out Threshold"
                value = var.scale_out_cpu_threshold
              },
              {
                label = "Scale In Threshold"
                value = var.scale_in_cpu_threshold
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/NetworkELB", "HealthyHostCount", { 
              stat = "Average",
              dimensions = {
                LoadBalancer = module.load_balancer.nlb_arn
              }
            }],
            [".", "UnHealthyHostCount", {
              stat = "Average",
              dimensions = {
                LoadBalancer = module.load_balancer.nlb_arn
              }
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Load Balancer Host Health"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EFS", "ClientConnections", {
              stat = "Sum",
              dimensions = {
                FileSystemId = module.storage.efs_id
              }
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EFS Client Connections"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", {
              stat = "Average",
              dimensions = {
                AutoScalingGroupName = module.compute.autoscaling_group_name
              }
            }],
            [".", "GroupInServiceInstances", {
              stat = "Average",
              dimensions = {
                AutoScalingGroupName = module.compute.autoscaling_group_name
              }
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Auto Scaling Group Instances"
          period  = 300
        }
      }
    ]
  })
}