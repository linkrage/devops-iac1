output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "instance_security_group_id" {
  value = aws_security_group.instances.id
}
