# -----------------------------------------------------------------------------
# terraform-aws-webserver-cluster
# Module version: v0.0.2
# 
# Creates an Auto Scaling Group of web servers behind an Application Load
# Balancer, with security groups, launch template, and CloudWatch alarms.
#
# GOTCHA NOTE: All file references use path.module so this module resolves
# paths correctly regardless of where Terraform is run from.
# GOTCHA NOTE: Security group rules are defined as SEPARATE resources
# (aws_security_group_rule), NOT inline blocks, so callers can inject
# additional rules without conflicting with module-managed rules.
# -----------------------------------------------------------------------------

# Data Sources

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availabilityZone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

# Launch Template

resource "aws_launch_template" "this" {
  name_prefix   = "${var.cluster_name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  # GOTCHA FIX: Use path.module so the file path resolves relative to the
  # MODULE directory, not wherever `terraform apply` is run from.

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    app_name    = var.cluster_name
  }))

  vpc_security_group_ids = [aws_security_group.instance.id]

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.extra_tags, {
      Name = var.cluster_name
    })
  }
}

# Auto Scaling Group

resource "aws_autoscaling_group" "this" {
  name                = var.cluster_name
  vpc_zone_identifier = data.aws_subnets.default.ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.this.arn]
  health_check_type = "ELB"

  # v0.0.2 addition: configurable health check grace period
  health_check_grace_period = var.health_check_grace_period

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.extra_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer

resource "aws_lb" "this" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]

  tags = merge(var.extra_tags, {
    Name = var.cluster_name
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "this" {
  name     = var.cluster_name
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# -----------------------------------------------------------------------------
# Security Groups — NOTE: Using SEPARATE rule resources, NOT inline blocks.
#
# GOTCHA: If you mix aws_security_group inline ingress/egress blocks AND
# aws_security_group_rule resources for the same security group, Terraform
# will fight itself on every apply and may remove rules unexpectedly.
# Pick one approach. This module uses separate resources so callers can
# add rules externally without modifying this module.
# -----------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name   = "${var.cluster_name}-instance"
  vpc_id = data.aws_vpc.default.id

  tags = merge(var.extra_tags, {
    Name = "${var.cluster_name}-instance"
  })

  # Lifecycle ensures new SG is created before old one is destroyed
  lifecycle {
    create_before_destroy = true
  }
}

# Separate rule resources — callers can add more rules without touching this module
resource "aws_security_group_rule" "instance_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instance.id
  from_port         = var.server_port
  to_port           = var.server_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "instance_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.instance.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "alb" {
  name   = "${var.cluster_name}-alb"
  vpc_id = data.aws_vpc.default.id

  tags = merge(var.extra_tags, {
    Name = "${var.cluster_name}-alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = var.alb_port
  to_port           = var.alb_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}


# CloudWatch Alarms (v0.0.2 addition)

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "CPU utilization above ${var.cpu_alarm_threshold}% for ${var.cluster_name}"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  tags = var.extra_tags
}
