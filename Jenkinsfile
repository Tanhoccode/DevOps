pipeline {
    agent any
    
    options {
        timeout(time: 20, unit: 'MINUTES') // Tăng timeout lên 30 phút ne
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    environment {
        DOCKER_IMAGE = "nest-app"
        DOCKER_TAG = "${BUILD_NUMBER}"
        EC2_HOST = "13.214.38.4"
        EC2_USER = "ubuntu"
        APP_DIR = "/home/ubuntu/nest-docker"
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
                    sshagent(['SSH-keygen-1']) {
                        sh '''
                            ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} "echo 'Connection successful'"
                        '''
                    }
                }
            }
        }
        
        stage('Deploy Application') {
            options {
                timeout(time: 25, unit: 'MINUTES') // Timeout riêng cho stage này 
            }
            steps {
                script {
                    echo 'Starting deployment to EC2...'
                    sshagent(['SSH-keygen-1']) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'EOF'
                            set -e
                            
                            echo "=== Starting deployment process ==="
                            
                            # Cleanup old directory if exists
                            rm -rf ${APP_DIR}
                            
                            # Clone repository
                            echo "Cloning repository..."
                            git clone git@github.com:Tanhoccode/DevOps.git ${APP_DIR}
                            cd ${APP_DIR}
                            
                            echo "=== Current commit: $(git rev-parse --short HEAD) ==="
                            
                            # Stop and remove old containers/images
                            echo "Cleaning up old containers and images..."
                            docker stop nest-app-container 2>/dev/null || echo "No container to stop"
                            docker rm nest-app-container 2>/dev/null || echo "No container to remove"
                            docker rmi ${DOCKER_IMAGE}:latest 2>/dev/null || echo "No old image to remove"
                            
                            # Prune unused Docker resources to free up space
                            docker system prune -f
                            
                            echo "Building new Docker image..."
                            # Build with more verbose output and optimizations
                            DOCKER_BUILDKIT=1 docker build \
                                --no-cache \
                                --progress=plain \
                                --build-arg BUILDKIT_INLINE_CACHE=1 \
                                -t ${DOCKER_IMAGE}:latest \
                                -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                            
                            echo "Starting new container..."
                            docker run -d \
                                --name nest-app-container \
                                --restart unless-stopped \
                                -p 3000:3000 \
                                ${DOCKER_IMAGE}:latest
                            
                            echo "=== Deployment completed successfully ==="
                            
                            # Wait a moment for container to start
                            sleep 5
                            
                            # Check if container is running
                            if docker ps | grep nest-app-container; then
                                echo "Container is running successfully"
                            else
                                echo "Container failed to start"
                                docker logs nest-app-container
                                exit 1
                            fi
EOF
                        '''
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo 'Performing health check...'
                    sshagent(['SSH-keygen-1']) {
                        sh '''
                            # Wait for application to be ready
                            sleep 10
                            
                            ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'EOF'
                            # Check if container is running
                            if docker ps | grep nest-app-container; then
                                echo "✅ Container is running"
                            else
                                echo "❌ Container is not running"
                                exit 1
                            fi
                            
                            # Check if application responds (optional)
                            # curl -f http://localhost:3000/health || echo "Health check endpoint not available"
                            
                            echo "🎉 Health check passed!"
EOF
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
        success {
            echo '🎉 Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        aborted {
            echo '⚠️ Pipeline was aborted!'
        }
    }
}