variable "project"             { type = string }
variable "private_subnets"     { type = list(string) }
variable "target_group_arn"    { type = string }
variable "app_sg_id"           { type = string }
variable "instance_type"       { default = "t3.micro" }
variable "min_size"            { default = 2 }
variable "max_size"            { default = 6 }
variable "desired_capacity"    { default = 2 }
variable "userdata_path"       { type = string }

# ---- Latest Amazon Linux 2023 AMI ----
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---- IAM role for EC2 (SSM + CloudWatch) ----
resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ---- Launch template ----
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile { name = aws_iam_instance_profile.ec2.name }

  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(file(var.userdata_path))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project}-app" }
  }

  lifecycle { create_before_destroy = true }
}

# ---- ASG ----
resource "aws_autoscaling_group" "app" {
  name                = "${var.project}-asg"
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [var.target_group_arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences { min_healthy_percentage = 50 }
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle { create_before_destroy = true }
}

# ---- Scaling policies (CPU) ----
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = { AutoScalingGroupName = aws_autoscaling_group.app.name }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = { AutoScalingGroupName = aws_autoscaling_group.app.name }
}

output "asg_name" { value = aws_autoscaling_group.app.name }