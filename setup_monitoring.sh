#!/bin/bash

echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo docker --version

echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

echo "Trying to run the Docker service..."
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl status docker --no-pager
echo "Docker services are running successfully."

# Check if the user is part of the Docker group
echo "Checking if the user is part of the Docker group..."
sudo usermod -aG docker $USER
sudo systemctl restart docker
echo "User $USER is now part of the Docker group, you do not need to use sudo anymore."

# Creating the directory structure for monitoring
echo "Setting up monitoring directory..."
mkdir -p ~/monitoring/data/prometheus/config ~/monitoring/data/prometheus/data ~/monitoring/data/grafana

echo "Creating docker-compose.yml..."
cat <<EOF > ~/monitoring/docker-compose.yml
services:
  prometheus: 
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes: 
      - ./data/prometheus/config:/etc/prometheus/
      - ./data/prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    expose:
      - 9091
    ports: 
      - "9091:9091"
    links:
      - cadvisor:cadvisor
      - node-exporter:node-exporter

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped 
    expose: 
      - 9100

  cadvisor: 
    image: gcr.io/cadvisor/cadvisor
    container_name: cadvisor
    restart: unless-stopped
    volumes: 
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    ports:
      - "8080:8080"
    privileged: true
    expose: 
      - 8080

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    links: 
      - prometheus:prometheus
    volumes: 
      - ./data/grafana:/var/lib/grafana
    environment: 
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3000:3000"
EOF

SERVER_IP=$(hostname -I | awk '{print $1}')

# Here we used dynamic IP replacement when it came to the server's IP
echo "Creating prometheus.yml..."
cat <<EOF > ~/monitoring/data/prometheus/config/prometheus.yml
global: 
  scrape_interval: 60s
  evaluation_interval: 60s
  external_labels:
    monitor: 'my-project'

rule_files:
  # - "alert.rules"
  # - "first.rules"
  # - "second.rules"

scrape_configs: 
  - job_name: 'prometheus'
    scrape_interval: 60s
    static_configs:
      - targets: ['$SERVER_IP:9091', 'cadvisor:8080', 'node-exporter:9100', 'nginx-exporter:9113'] 
EOF

# Change directory permissions to allow user access as root, this is very important because otherwise the privileged of the docker-compose won't work and it will break the cadvisor container.
echo "Granting permissions to the monitoring directory..."
cd ~
sudo chmod -R 777 ~/monitoring

echo "Verifying permissions for 'monitoring' directory..."
ls -ld ~/monitoring
ls -l ~/monitoring/data/prometheus/config

sudo systemctl restart docker
newgrp docker

echo "Starting Docker Compose stack..."
cd ~/monitoring
docker-compose up -d

echo "Monitoring setup completed successfully!"
docker ps
