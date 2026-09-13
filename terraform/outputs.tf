output "ec2_public_ip" {
  description = "IP Público da Instancia EC2 simulada"
  value       = aws_instance.api_server.public_ip
}
