resource "aws_iam_role" "ec2_role" {
  name = "api-consultas-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "api-consultas-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "api_server" {
  # AMI universal suportada nativamente pelo LocalStack
  ami                    = "ami-df5db4b0" 
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  # Comentado para compatibilidade com o LocalStack (Mapeado no skip do Checkov do CI)
  # monitoring             = true 

  # Comentado para o LocalStack não quebrar tentando validar criptografia física
  # root_block_device {
  #   encrypted = true
  # }

  # Comentado para o LocalStack não travar na simulação de tokens do IMDSv2
  # metadata_options {
  #   http_endpoint               = "enabled"
  #   http_tokens                 = "required"
  #   http_put_response_hop_limit = 1
  # }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              mkdir -p /usr/local/lib/docker/cli-plugins/
              curl -SL https://github.com -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
              EOF

  tags = {
    Name = "api-consultas-ec2"
  }
}
