output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "endpoint_security_group_id" {
  value = aws_security_group.endpoints.id
}

output "private_route_table_ids" {
  value = [for rt in aws_route_table.private : rt.id]
}

output "public_route_table_ids" {
  value = [for rt in aws_route_table.public : rt.id]
}

output "interface_endpoint_ids" {
  value = [for endpoint in aws_vpc_endpoint.interface : endpoint.id]
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}
