# Network Load Balancer
resource "aws_lb" "chia" {
  name               = "${var.project_name}-${var.environment}-chia-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-nlb"
  })
}

# Target Group for Chia fullnode port
resource "aws_lb_target_group" "chia_fullnode" {
  name     = "${var.project_name}-${var.environment}-chia-fullnode"
  port     = var.chia_port
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    port                = var.chia_port
    protocol            = "TCP"
  }

  deregistration_delay = 30

  stickiness {
    enabled = true
    type    = "source_ip"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-fullnode-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for Chia RPC port
resource "aws_lb_target_group" "chia_rpc" {
  name     = "${var.project_name}-${var.environment}-chia-rpc"
  port     = var.chia_rpc_port
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    port                = var.chia_rpc_port
    protocol            = "TCP"
  }

  deregistration_delay = 30

  stickiness {
    enabled = true
    type    = "source_ip"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-rpc-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for health check endpoint (HTTP)
resource "aws_lb_target_group" "chia_health" {
  name     = "${var.project_name}-${var.environment}-chia-health"
  port     = 8080
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
    port                = 8080
    protocol            = "TCP"
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-health-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Listener for Chia fullnode port
resource "aws_lb_listener" "chia_fullnode" {
  load_balancer_arn = aws_lb.chia.arn
  port              = var.chia_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chia_fullnode.arn
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-fullnode-listener"
  })
}

# Listener for Chia RPC port
resource "aws_lb_listener" "chia_rpc" {
  load_balancer_arn = aws_lb.chia.arn
  port              = var.chia_rpc_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chia_rpc.arn
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-rpc-listener"
  })
}

# CloudWatch alarms for NLB health
resource "aws_cloudwatch_metric_alarm" "nlb_healthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-nlb-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when we have less than 1 healthy host"
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.chia_fullnode.arn_suffix
    LoadBalancer = aws_lb.chia.arn_suffix
  }
}

# CloudWatch alarm for unhealthy hosts
resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-nlb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Alert when we have unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.chia_fullnode.arn_suffix
    LoadBalancer = aws_lb.chia.arn_suffix
  }
}