output "instance_id" {
  value = aws_instance.this.id
}
output "private_ip" {
  value = aws_instance.this.private_ip
}
output "eni_id" {
  value = aws_instance.this.primary_network_interface_id
}
output "security_group_id" {
  value = aws_security_group.this.id
}
output "role_arn" {
  value = aws_iam_role.this.arn
}
output "role_name" {
  value = aws_iam_role.this.name
}
output "profile_name" {
  value = aws_iam_instance_profile.this.name
}
output "ami_id" {
  value = aws_instance.this.ami
}
