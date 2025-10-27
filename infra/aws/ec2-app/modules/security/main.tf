resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "ALB entry"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "instances" {
  name        = "${var.name_prefix}-instances"
  description = "Instance ingress from ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-instances-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Remove any inline rules from the security group to allow separate rule resources
resource "terraform_data" "cleanup_inline_sg_rules" {
  triggers_replace = {
    sg_id   = aws_security_group.instances.id
    version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      SG_ID="${aws_security_group.instances.id}"
      
      # Revoke all existing ingress rules (inline rules from previous apply)
      aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' > /tmp/sg_ingress_cleanup.json 2>/dev/null || true
      if [ -s /tmp/sg_ingress_cleanup.json ] && [ "$(cat /tmp/sg_ingress_cleanup.json)" != "[]" ] && [ "$(cat /tmp/sg_ingress_cleanup.json)" != "null" ]; then
        aws ec2 revoke-security-group-ingress --group-id $SG_ID --ip-permissions file:///tmp/sg_ingress_cleanup.json 2>/dev/null || true
      fi
      
      # Revoke all existing egress rules
      aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissionsEgress' > /tmp/sg_egress_cleanup.json 2>/dev/null || true
      if [ -s /tmp/sg_egress_cleanup.json ] && [ "$(cat /tmp/sg_egress_cleanup.json)" != "[]" ] && [ "$(cat /tmp/sg_egress_cleanup.json)" != "null" ]; then
        aws ec2 revoke-security-group-egress --group-id $SG_ID --ip-permissions file:///tmp/sg_egress_cleanup.json 2>/dev/null || true
      fi
      
      # Clean up temp files
      rm -f /tmp/sg_ingress_cleanup.json /tmp/sg_egress_cleanup.json
    EOT
  }

  depends_on = [aws_security_group.instances]
}

# Separate rules to allow dynamic updates without replacement
resource "aws_security_group_rule" "instances_http_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "HTTP from ALB"
  security_group_id        = aws_security_group.instances.id

  depends_on = [terraform_data.cleanup_inline_sg_rules]
}

resource "aws_security_group_rule" "instances_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_ingress_cidrs
  description       = "SSH access"
  security_group_id = aws_security_group.instances.id

  depends_on = [terraform_data.cleanup_inline_sg_rules]
}

resource "aws_security_group_rule" "instances_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instances.id

  depends_on = [terraform_data.cleanup_inline_sg_rules]
}
