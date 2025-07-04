# AWS Region Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "chia-autoscaling"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# Compute Configuration
variable "instance_type" {
  description = "EC2 instance type for Chia nodes"
  type        = string
  default     = "c5.xlarge"
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH access"
  type        = string
}

variable "ami_id" {
  description = "AMI ID with Chia pre-installed (leave empty to use latest Ubuntu)"
  type        = string
  default     = ""
}

# Auto Scaling Configuration
variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 10
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 3
}

variable "scale_out_cpu_threshold" {
  description = "CPU threshold for scaling out"
  type        = number
  default     = 70
}

variable "scale_in_cpu_threshold" {
  description = "CPU threshold for scaling in"
  type        = number
  default     = 30
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 600
}

# Chia Configuration
variable "chia_port" {
  description = "Chia fullnode port"
  type        = number
  default     = 8444
}

variable "chia_rpc_port" {
  description = "Chia RPC port"
  type        = number
  default     = 8555
}

variable "chia_farmer_port" {
  description = "Chia farmer port"
  type        = number
  default     = 8447
}

# Storage Configuration
variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

variable "backup_retention_days" {
  description = "S3 backup retention days"
  type        = number
  default     = 30
}

# Monitoring Configuration
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "ChiaAutoscaling"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}