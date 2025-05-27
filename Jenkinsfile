pipeline {
    agent any
    
    environment {
        EC2_HOST = '13.214.166.36'
        EC2_USER = 'ubuntu'
        REPO_URL = 'https://github.com/Tanhoccode/DevOps.git'
        PROJECT_DIR = 'nest-docker'
        DOCKER_IMAGE = 'nest-app'
        DOCKER_CONTAINER = 'nest-container'
        APP_PORT = '3000'
    }
    
    options {
        // Giữ lại 10 build gần nhất ne
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Timeout cho toàn bộ pipeline
        timeout(time: 10, unit: 'MINUTES')
        // Không cho phép build đồng thời
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        
        stage('Pre-deployment Check') {
            steps {
                script {
                    echo 'Checking EC2 connection...'
                    sshagent(['ec2-ssh-key']) {
                        sh """
                            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} 'echo "Connection successful"'
                        """
                    }
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    echo 'Starting deployment to EC2...'
                    sshagent(['ec2-ssh-key']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'ENDSSH'
                                set -e  # Exit on any error
                                
                                echo "=== Starting deployment process ==="
                                
                                # Tạo thư mục backup nếu cần rollback
                                mkdir -p ~/backups
                                
                                # Clone hoặc update source code
                                if [ ! -d "~/${PROJECT_DIR}" ]; then
                                    echo "Cloning repository..."
                                    git clone ${REPO_URL} ~/${PROJECT_DIR}
                                else
                                    echo "Updating existing repository..."
                                    cd ~/${PROJECT_DIR}
                                    git fetch --all
                                    git reset --hard origin/main
                                    git pull origin main
                                fi
                                
                                cd ~/${PROJECT_DIR}
                                
                                echo "=== Current commit: \$(git rev-parse --short HEAD) ==="
                                
                                # Backup current running container (nếu có)
                                if docker ps -q -f name=${DOCKER_CONTAINER} | grep -q .; then
                                    echo "Backing up current container..."
                                    docker commit ${DOCKER_CONTAINER} ${DOCKER_IMAGE}:backup-\$(date +%Y%m%d-%H%M%S) || true
                                fi
                                
                                # Stop và remove container cũ
                                echo "Stopping old container..."
                                docker stop ${DOCKER_CONTAINER} 2>/dev/null || echo "No container to stop"
                                docker rm ${DOCKER_CONTAINER} 2>/dev/null || echo "No container to remove"
                                
                                # Xóa image cũ để build mới
                                docker rmi ${DOCKER_IMAGE}:latest 2>/dev/null || echo "No old image to remove"
                                
                                # Build image mới
                                echo "Building new Docker image..."
                                docker build -t ${DOCKER_IMAGE}:latest .
                                
                                # Chạy container mới
                                echo "Starting new container..."
                                docker run -d \\
                                    --name ${DOCKER_CONTAINER} \\
                                    --restart unless-stopped \\
                                    -p ${APP_PORT}:${APP_PORT} \\
                                    --health-cmd="curl -f http://localhost:${APP_PORT}/health || exit 1" \\
                                    --health-interval=30s \\
                                    --health-timeout=10s \\
                                    --health-retries=3 \\
                                    ${DOCKER_IMAGE}:latest
                                
                                echo "=== Deployment completed ==="
                                
                                # Cleanup old images (giữ lại 3 images gần nhất)
                                echo "Cleaning up old images..."
                                docker images ${DOCKER_IMAGE} --format "table {{.Repository}}:{{.Tag}}\\t{{.CreatedAt}}\\t{{.ID}}" | tail -n +2 | sort -k2 -r | tail -n +4 | awk '{print \$3}' | xargs -r docker rmi || true
ENDSSH
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo 'Performing health check...'
                    sshagent(['ec2-ssh-key']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'ENDSSH'
                                echo "Waiting for application to be ready..."
                                sleep 10
                                
                                # Kiểm tra container có đang chạy không
                                if ! docker ps | grep -q ${DOCKER_CONTAINER}; then
                                    echo "ERROR: Container is not running!"
                                    docker logs ${DOCKER_CONTAINER} --tail 50
                                    exit 1
                                fi
                                
                                # Kiểm tra port có mở không
                                if ! nc -z localhost ${APP_PORT}; then
                                    echo "ERROR: Application is not responding on port ${APP_PORT}"
                                    docker logs ${DOCKER_CONTAINER} --tail 50
                                    exit 1
                                fi
                                
                                echo "✅ Application is running successfully!"
                                echo "🔗 Access URL: http://${EC2_HOST}:${APP_PORT}"
ENDSSH
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '🎉 Deployment completed successfully!'
            // Có thể thêm notification
            script {
                currentBuild.description = "✅ Deployed to ${EC2_HOST}:${APP_PORT}"
            }
        }
        
        failure {
            echo '❌ Deployment failed!'
            script {
                currentBuild.description = "❌ Deployment failed"
                // Có thể thêm rollback logic ở đây
                sshagent(['ec2-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'ENDSSH' || true
                            echo "Attempting to get logs for debugging..."
                            docker logs ${DOCKER_CONTAINER} --tail 100 || true
ENDSSH
                    """ 
                }
            }
        }
        
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}