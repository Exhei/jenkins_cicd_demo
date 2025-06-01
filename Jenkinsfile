pipeline {
    agent any
    environment {
        APP_SERVER_IP = '51.21.218.128'
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
                            pm2 start index.js --name app
                        '
                    """
                }
            }
        }
    }
}
