pipeline {
    agent any
    environment {
        APP_SERVER_IP = '13.61.5.117'
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
                        scp -o StrictHostKeyChecking=no -r ./dist/* ec2-user@\${APP_SERVER_IP}:/home/ec2-user/app/
                        ssh -o StrictHostKeyChecking=no ec2-user@\${APP_SERVER_IP} << 'ENDSSH'
                            sudo npm install -g pm2
                            pm2 stop all || true
                            pm2 start /home/ec2-user/app/index.js --name app
                        ENDSSH
                    """
                }
            }
        }
    }
}