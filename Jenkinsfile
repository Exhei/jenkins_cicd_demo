pipeline {
    agent any
    environment {
        APP_SERVER = '13.61.5.117' // Replace with your app EC2 public IP
        SSH_CREDENTIALS = credentials('app-ec2-ssh') // Jenkins SSH credentials ID
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/exhei/jenkins_cicd_demo.git'
            }
        }
        stage('Build') {
            steps {
                sh 'npm install'
            }
        }
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        stage('Deploy') {
            steps {
                sshagent(['app-ec2-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ec2-user@$APP_SERVER << EOF
                            rm -rf /home/ec2-user/app/*
                            mkdir -p /home/ec2-user/app
                        EOF
                        scp -r * ec2-user@$APP_SERVER:/home/ec2-user/app
                        ssh -o StrictHostKeyChecking=no ec2-user@$APP_SERVER << EOF
                            cd /home/ec2-user/app
                            npm install
                            nohup npm start &
                        EOF
                    '''
                }
            }
        }
    }
}