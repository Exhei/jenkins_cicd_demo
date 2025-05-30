pipeline {
    agent any
    environment {
        APP_SERVER = '13.53.124.245' // Replace with your app EC2 public IP
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
                sshagent(credentials: ['app-ec2-ssh']) {
                    sh """
                        scp -o StrictHostKeyChecking=no -r ./dist/* ec2-user@\${APP_SERVER_IP}:/home/ec2-user/app/
                        ssh -o StrictHostKeyChecking=no ec2-user@\${APP_SERVER_IP} << 'ENDSSH'
                            npm install -g pm2
                            pm2 stop all || true
                            pm2 start /home/ec2-user/app/index.js --name app
                        ENDSSH
                    """
                }
            }
        }
    }
}