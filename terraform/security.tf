resource "aws_security_group" "ec2_sg" {
  name        = "api-consultas-ec2-sg"
  description = "Permitir trafego para a API Node.js e SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Permitir acesso publico a API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Acesso SSH restrito para administradores"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.1.0/24"]
  }

  egress {
    description = "Permitir atualizacoes de pacotes via HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permitir atualizacoes de pacotes via HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
