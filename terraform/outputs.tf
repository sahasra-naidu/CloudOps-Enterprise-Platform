output "vpc_id" {
  description = "ID of the CloudOps VPC"
  value       = aws_vpc.cloudops_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private_subnet.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.cloudops_sg.id
}

output "ec2_instance_id" {
  description = "ID of the CloudOps EC2 instance"
  value       = aws_instance.cloudops_server.id
}

output "ec2_public_ip" {
  description = "Public IP of the CloudOps EC2 instance"
  value       = aws_instance.cloudops_server.public_ip
}