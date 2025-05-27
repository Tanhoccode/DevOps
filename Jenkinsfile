stage('Deploy Application') {
    steps {
        script {
            echo 'Starting deployment to EC2...'
            sshagent(['ec2-ssh-key']) {
                sh """
                    ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'ENDSSH'
                        set -euo pipefail
                        trap 'echo "❌ Deployment failed!" >&2' ERR

                        echo "=== Starting deployment ==="
                        PROJECT_DIR="$HOME/${PROJECT_DIR}"

                        if [ ! -d "\$PROJECT_DIR" ]; then
                            echo "Cloning project..."
                            git clone ${REPO_URL} \$PROJECT_DIR
                        else
                            echo "Updating project..."
                            cd \$PROJECT_DIR
                            git fetch --all
                            git reset --hard origin/main
                            git pull origin main
                        fi

                        cd \$PROJECT_DIR

                        echo "Stopping old container..."
                        docker stop ${DOCKER_CONTAINER} 2>/dev/null || true
                        docker rm ${DOCKER_CONTAINER} 2>/dev/null || true
                        docker rmi ${DOCKER_IMAGE}:latest 2>/dev/null || true

                        echo "Building image..."
                        docker build -t ${DOCKER_IMAGE}:latest .

                        echo "Running container..."
                        docker run -d \\
                            --name ${DOCKER_CONTAINER} \\
                            --restart unless-stopped \\
                            -p ${APP_PORT}:${APP_PORT} \\
                            --health-cmd="curl -f http://localhost:${APP_PORT}/health || exit 1" \\
                            --health-interval=30s \\
                            --health-timeout=10s \\
                            --health-retries=3 \\
                            ${DOCKER_IMAGE}:latest

                        echo "Cleaning up old images..."
                        docker images ${DOCKER_IMAGE} --format "{{.Repository}}:{{.Tag}}\\t{{.CreatedAt}}\\t{{.ID}}" \\
                            | tail -n +2 | sort -k2 -r | tail -n +4 | awk '{print \$3}' | xargs -r docker rmi || true

                        echo "✅ Deployment successful"
                    ENDSSH
                """
            }
        }
    }
}
