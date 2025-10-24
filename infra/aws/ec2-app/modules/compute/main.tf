locals {
  user_data = templatefile("${path.module}/userdata.sh.tmpl", {
    runtime_banner = var.runtime_banner
    runtime_color  = var.runtime_color
  })

  merged_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = var.security_group_ids
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_id
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.merged_tags, {
      Name = "${var.name_prefix}-ec2"
      Role = "web"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.merged_tags, {
      Name = "${var.name_prefix}-vol"
    })
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name_prefix}-asg"
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_capacity
  max_size                  = var.max_capacity
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 90
  target_group_arns         = var.target_group_arns
  capacity_rebalance        = true

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  dynamic "tag" {
    for_each = merge(local.merged_tags, {
      Name = "${var.name_prefix}-asg"
      Role = "web"
    })
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
