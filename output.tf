output "aws_server_1_ip" {
  value = aws_instance.app_server_1.public_ip
}
output "app_server_2_ip" {
  value = aws_instance.app_server_2.public_ip
}
output "aws_vpc_id" {
  value = aws_vpc.frankVPC.id
}