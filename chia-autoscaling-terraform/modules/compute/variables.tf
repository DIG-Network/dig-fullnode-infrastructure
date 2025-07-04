variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of subnets for Auto Scaling Group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH access"
  type        = string
}

variable "ami_id" {
  description = "AMI ID (leave empty to use latest Ubuntu)"
  type        = string
}

variable "user_data_script" {
  description = "User data script content"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of instances"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
}

variable "scale_out_cpu_threshold" {
  description = "CPU threshold for scaling out"
  type        = number
}

variable "scale_in_cpu_threshold" {
  description = "CPU threshold for scaling in"
  type        = number
}

variable "target_group_arns" {
  description = "Target group ARNs for load balancer"
  type        = list(string)
  default     = []
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}