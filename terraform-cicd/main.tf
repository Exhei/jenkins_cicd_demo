provider "aws" {
  region = "eu-north-1"
}

resource "aws_instance" "jenkins" {
  ami           = "ami-00f34bf9aeacdf007" # Amazon Linux 2023 AMI for eu-north-1
  instance_type = "t3.micro"
  key_name      = var.key_pair
  security_groups = [aws_security_group.cicd_sg.name]
  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > /var/log/user-data.log 2>&1
              sudo yum update -y
              sudo yum install -y java-11-amazon-corretto
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              sudo yum install -y https://mirrors.jenkins.io/redhat-stable/jenkins-2.440.3-1.1.noarch.rpm || echo "Jenkins install failed" >> /var/log/user-data.log
              sudo systemctl daemon-reload
              # Wait for systemd to be ready
              sleep 10
              for i in {1..10}; do
                if sudo systemctl start jenkins; then
                  echo "Jenkins started successfully" >> /var/log/user-data.log
                  break
                else
                  echo "Jenkins start attempt $i failed" >> /var/log/user-data.log
                  sleep 10
                fi
              done
              sudo systemctl enable jenkins || echo "Jenkins enable failed" >> /var/log/user-data.log
              sudo yum install -y git
              sudo curl -sL https://rpm.nodesource.com/setup_14.x | bash -
              sudo yum install -y nodejs
              EOF
  tags = {
    Name = "JenkinsServer"
  }
}

resource "aws_instance" "app" {
  ami           = "ami-00f34bf9aeacdf007"
  instance_type = "t3.micro"
  key_name      = var.key_pair
  security_groups = [aws_security_group.cicd_sg.name]
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo curl -sL https://rpm.nodesource.com/setup_14.x | bash -
              sudo yum install -y nodejs
              sudo mkdir -p /home/ec2-user/app
              sudo chown ec2-user:ec2-user /home/ec2-user/app
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