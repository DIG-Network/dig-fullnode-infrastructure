# Data source for latest Ubuntu AMI if not specified
data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Local variable for AMI ID
locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
}

# Launch template for Chia nodes
resource "aws_launch_template" "chia_node" {
  name_prefix   = "${var.project_name}-${var.environment}-chia-node-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # Use gp3 for better performance
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 500  # 500GB for blockchain data
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Additional volume for temporary storage
  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(var.user_data_script)

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-chia-node"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-chia-node-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-launch-template"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "chia_nodes" {
  name_prefix         = "${var.project_name}-${var.environment}-chia-asg-"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  min_size             = var.asg_min_size
  max_size             = var.asg_max_size
  desired_capacity     = var.asg_desired_capacity
  health_check_type    = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.chia_node.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-chia-node"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# Scale out policy
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-${var.environment}-scale-out"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.chia_nodes.name
}

# Scale in policy
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-${var.environment}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.chia_nodes.name
}

# CloudWatch metric alarm for high CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  alarm_description   = "This metric monitors CPU utilization for scaling out"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.chia_nodes.name
  }
}

# CloudWatch metric alarm for low CPU
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_description   = "This metric monitors CPU utilization for scaling in"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.chia_nodes.name
  }
}

# CloudWatch log group for Chia logs
resource "aws_cloudwatch_log_group" "chia_logs" {
  name              = "/aws/ec2/chia/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = var.tags
}

# Target tracking scaling policy for more responsive scaling
resource "aws_autoscaling_policy" "target_tracking" {
  name                   = "${var.project_name}-${var.environment}-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.chia_nodes.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}