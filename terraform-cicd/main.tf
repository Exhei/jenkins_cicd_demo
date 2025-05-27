provider "aws" {
  region = "eu-north-1"
}

resource "aws_instance" "jenkins" {
  ami           = "ami-00f34bf9aeacdf007" # Amazon Linux 2023 AMI for eu-north-1
  instance_type = "t3.micro" # Free Tier eligible
  key_name      = var.key_pair
  security_groups = [aws_security_group.cicd_sg.name]
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java-17-amazon-corretto
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              yum install -y jenkins
              systemctl daemon-reload
              systemctl start jenkins
              systemctl enable jenkins
              yum install -y git
              curl -sL https://rpm.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              EOF
  tags = {
    Name = "JenkinsServer"
  }
}

resource "aws_instance" "app" {
  ami           = "ami-00f34bf9aeacdf007" # Amazon Linux 2023 AMI for eu-north-1
  instance_type = "t3.micro" # Free Tier eligible
  key_name      = var.key_pair
  security_groups = [aws_security_group.cicd_sg.name]
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              curl -sL https://rpm.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              mkdir -p /home/ec2-user/app
              chown ec2-user:ec2-user /home/ec2-user/app
              EOF
  tags = {
    Name = "AppServer"
  }
}

resource "aws_security_group" "cicd_sg" {
  name        = "cicd-security-group"
  description = "Allow SSH, HTTP, and Jenkins"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "key_pair" {
  description = "EC2 Key Pair for SSH access"
  type        = string
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "app_public_ip" {
  value = aws_instance.app.public_ip
}