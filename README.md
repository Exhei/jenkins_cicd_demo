# Jenkins CI/CD Demo Setup Guide

This guide provides detailed instructions to configure a Jenkins CI/CD pipeline for deploying a Node.js application to an AWS EC2 instance, integrated with a GitHub repository (`https://github.com/Exhei/jenkins_cicd_demo`) and managed via Terraform. The setup includes a Jenkins server and an application server (`APP_SERVER_IP`).

## Prerequisites
- **AWS Account**: Access to EC2 instances with a key pair (`cicd_demo.pem`).
- **GitHub Account**: Access to `https://github.com/Exhei/jenkins_cicd_demo`.
- **Terraform**: Installed locally for infrastructure management.
- **Node.js**: Installed on the Jenkins and app servers.
- **Jenkins**: Running at `http://<jenkins_public_ip>:8080` (IP from Terraform output).
- **AWS CLI**: Install AWS CLI Locally.
- **Local Setup**: Clone the repository:
  ```bash
  cd ~/git/jenkins_cicd_demo
  git clone https://github.com/Exhei/jenkins_cicd_demo.git
  cd jenkins_cicd_demo
  ```

## Setup Steps

### 1. Configure the GitHub Repository
1. **Create Application Files**:
   - Create a `src` directory with `index.js`:
     ```bash
     mkdir src
     cat > src/index.js << 'EOF'
     const express = require('express');
     const app = express();

     app.get('/', (req, res) => res.send('Hello from Jenkins CICD Demo!'));

     app.listen(3000, () => console.log('App running on port 3000'));
     EOF
     ```
   - Create `package.json`:
     ```json
     {
       "name": "jenkins-cicd-demo",
       "version": "1.0.0",
       "scripts": {
         "build": "mkdir -p dist && cp -r src/* dist/",
         "start": "node src/index.js"
       },
       "dependencies": {
         "express": "^4.17.1"
       }
     }
     ```
   - Create `Jenkinsfile`:
     ```groovy
     pipeline {
         agent any
         environment {
             APP_SERVER_IP = '$APP_SERVER_IP'
         }
         stages {
             stage('Checkout') {
                 steps {
                     git url: 'https://github.com/Exhei/jenkins_cicd_demo.git', branch: 'main'
                 }
             }
             stage('Build') {
                 steps {
                     sh 'npm install'
                     sh 'npm run build'
                 }
             }
             stage('Deploy') {
                 steps {
                     sshagent(credentials: ['app-ec2-ssh']) {
                         sh """
                             ssh -o StrictHostKeyChecking=no ec2-user@\${APP_SERVER_IP} 'mkdir -p /home/ec2-user/app'

                             scp -o StrictHostKeyChecking=no -r * ec2-user@\${APP_SERVER_IP}:/home/ec2-user/app/

                             ssh -o StrictHostKeyChecking=no ec2-user@\${APP_SERVER_IP} '
                                 cd /home/ec2-user/app &&
                                 npm install &&
                                 sudo npm install -g pm2 &&
                                 pm2 stop app || true &&
                                 pm2 start dist/index.js --name app
                             '
                         """
                     }
                 }
             }
         }
     }
     ```
   - Commit and push:
     ```bash
     git add src/index.js package.json Jenkinsfile
     git commit -m "Add index.js, package.json, and Jenkinsfile"
     git push origin main
     ```

2. **Verify Repository Structure**:
   - Ensure the repository contains:
     ```
     .
     ├── Jenkinsfile
     ├── package.json
     ├── src
     │   └── index.js
     ```

### 2. Provision Infrastructure with Terraform
1. **Create Terraform Configuration**:
   - Create `main.tf` in `~/git/jenkins_cicd_demo/terraform-cicd`:
     ```hcl
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
                   sudo yum install -y java-11-amazon-corretto # USING OLDER VERSION BECAUSE OF SMALL INSTANCE
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
     ```
   - Commit and push (if part of the repository):
     ```bash
     mkdir -p terraform-cicd
     mv main.tf terraform-cicd/
     git add terraform-cicd/main.tf
     git commit -m "Add Terraform configuration"
     git push origin main
     ```

2. **Apply Terraform**:
   - Navigate to the Terraform directory:
     ```bash
     cd ~/git/jenkins_cicd_demo/terraform-cicd
     ```
   - Initialize Terraform:
     ```bash
     terraform init
     ```
   - Apply the configuration:
     ```bash
     terraform apply -var="key_pair=cicd_demo" # KEY ACCESS CREATED IN AWS
     ```
   - Note the output IPs (`jenkins_public_ip` and `app_public_ip`).

### 3. Configure Jenkins
1. **Access Jenkins**:
   - Go to `http://<jenkins_public_ip>:8080` (from Terraform output).
   - Save the cicd_demo.pem key somewhere locally, I choose `$HOME`
   - Unlock Jenkins using the initial admin password:
     ```bash
     ssh -i ~/cicd_demo.pem ec2-user@<jenkins_public_ip>
     sudo cat /var/lib/jenkins/secrets/initialAdminPassword
     ```

2. **Install Node.js**:
   - Already installed via Terraform `user_data` on the Jenkins server. Verify:
     ```bash
     ssh -i ~/cicd_demo.pem ec2-user@<jenkins_public_ip>
     npm --version
     node --version
     ```

3. **Add SSH Credentials**:
   - Go to `http://<jenkins_public_ip>:8080/credentials/store/system/domain/_/`.
   - Add credentials for the app server:
     - **Kind**: SSH Username with private key
     - **ID**: `app-ec2-ssh`
     - **Username**: `ec2-user` # Matches name of user created in AWS
     - **Private Key**: Paste the contents of `~/cicd_demo.pem`.
     - Save.

4. **Configure Git Plugin**:
   - Go to `http://<jenkins_public_ip>:8080/manage` > **System** > **Git plugin**.
   - Check **Allow git hooks to run on the Jenkins Controller**.
   - Save.

5. **Set Up Pipeline**:
   - Create a new pipeline at `http://<jenkins_public_ip>:8080/newJob`.
   - Name: `CICDDemoPipeline`
   - Type: **Pipeline**
   - Configure:
     - **Build Triggers**: Check **GitHub hook trigger for GITScm polling**.
     - **Pipeline**:
       - **Definition**: Pipeline script from SCM
       - **SCM**: Git
       - **Repository URL**: `https://github.com/Exhei/jenkins_cicd_demo.git`
       - **Branch Specifier**: `*/main`
       - **Script Path**: `Jenkinsfile`
     - Save.

6. **Adjust /tmp Space**:
   - Go to `http://<jenkins_public_ip>:8080/computer/(built-in)/configure`.
   - Set **Free Temp Space Threshold** to `0.4GiB` (400 MiB).
   - In order to have the Node Online in order to run jobs make new threshhold.
   - Save.

### 4. Configure GitHub Webhook
1. Go to `https://github.com/Exhei/jenkins_cicd_demo` > **Settings** > **Webhooks**.
2. Add or update webhook:
   - **Payload URL**: `http://<jenkins_public_ip>:8080/github-webhook/`
   - **Content type**: `application/json`
   - **Events**: **Just the push event**
   - Save.
3. Check Jenkins logs for errors or successful webhooks sent

### 5. Test the Pipeline
1. **Manual Build**:
   - Trigger a build at `http://<jenkins_public_ip>:8080/job/CICDDemoPipeline`.
   - Monitor the console output.

2. **Webhook Trigger**:
   - Push a test commit:
     ```bash
     cd ~/git/jenkins_cicd_demo/jenkins_cicd_demo
     echo "# Test webhook" >> test.txt
     git add test.txt
     git commit -m "Test webhook"
     git push origin main
     ```
   - Verify a build triggers at `http://<jenkins_public_ip>:8080/job/CICDDemoPipeline`.

3. **Verify Application**:
   - Check the app:
     ```bash
     curl -v http://APP_SERVER_IP:3000
     ```
     Expect: `Hello, World! Deployed via Jenkins CI/CD!`.

### 6. Troubleshooting
1. **Authentication Errors**:
   - Ensure `app-ec2-ssh` credentials match `cicd_demo.pem`.
   - Test SSH:
     ```bash
     ssh -i ~/cicd_demo.pem ec2-user@APP_SERVER_IP
     ```

2. **Build Failures**:
   - Check `npm` version:
     ```bash
     ssh -i ~/cicd_demo.pem ec2-user@<jenkins_public_ip>
     npm --version
     ```
   - Verify `dist` folder:
     ```bash
     cd ~/git/jenkins_cicd_demo/jenkins_cicd_demo
     npm run build
     ls -l dist
     ```

3. **PM2 Issues**:
   - SSH into the app server:
     ```bash
     ssh -i ~/cicd_demo.pem ec2-user@APP_SERVER_IP
     ```
   - Check PM2:
     ```bash
     pm2 list
     ```
   - Restart app:
     ```bash
     pm2 restart app
     ```
   - Verify `index.js`:
     ```bash
     cat /home/ec2-user/app/dist/index.js
     ```

### 7. Additional Notes
- **App Server IP**: `APP_SERVER_IP`.
- **Jenkins Server IP**: From Terraform output (`jenkins_public_ip`).
- **File Naming**: Uses `index.js` in `src` and `dist/index.js` for deployment.
- **Security Groups**: Ensure TCP 3000 and 8080 are open from `0.0.0.0/0`.
- **Terraform**: Run `terraform apply` only for `aws_instance.app` to avoid affecting the Jenkins server.

## License
MIT License. See [LICENSE](LICENSE) for details.