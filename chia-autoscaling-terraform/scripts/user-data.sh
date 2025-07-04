#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Chia node initialization..."

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    nfs-common \
    awscli \
    jq \
    python3 \
    python3-pip \
    git \
    build-essential \
    python3-dev \
    python3-venv \
    lsb-release

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Mount EFS
EFS_ID="${efs_id}"
EFS_MOUNT_POINT="/mnt/efs"
LOCAL_BLOCKCHAIN_DIR="/home/ubuntu/.chia/mainnet/db"

echo "Creating EFS mount point..."
mkdir -p $${EFS_MOUNT_POINT}

echo "Mounting EFS..."
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $${EFS_ID}.efs.${aws_region}.amazonaws.com:/ $${EFS_MOUNT_POINT}

# Add to fstab for persistent mount
echo "$${EFS_ID}.efs.${aws_region}.amazonaws.com:/ $${EFS_MOUNT_POINT} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab

# Install Chia if not already installed
if ! command -v chia &> /dev/null; then
    echo "Installing Chia blockchain..."
    cd /home/ubuntu
    git clone https://github.com/Chia-Network/chia-blockchain.git -b latest --recurse-submodules
    cd chia-blockchain
    
    # Install Chia
    sh install.sh
    
    # Activate virtual environment
    . ./activate
    
    # Initialize Chia
    chia init
    
    # Configure Chia
    chia configure --set-node-introducer ""
    chia configure --set-fullnode-port ${chia_port}
    
    chown -R ubuntu:ubuntu /home/ubuntu/chia-blockchain
fi

# Create local blockchain directory
mkdir -p $${LOCAL_BLOCKCHAIN_DIR}
chown -R ubuntu:ubuntu /home/ubuntu/.chia

# Check if blockchain data exists on EFS
if [ -d "$${EFS_MOUNT_POINT}/blockchain_data" ] && [ -f "$${EFS_MOUNT_POINT}/blockchain_data/blockchain_v2_mainnet.sqlite" ]; then
    echo "Found blockchain data on EFS, copying to local storage..."
    
    # Copy blockchain data from EFS to local storage
    # Using rsync for efficient copying with progress
    apt-get install -y rsync
    rsync -avP --inplace $${EFS_MOUNT_POINT}/blockchain_data/* $${LOCAL_BLOCKCHAIN_DIR}/
    
    echo "Blockchain data copy completed."
else
    echo "No blockchain data found on EFS. Node will sync from scratch."
    echo "Creating blockchain data directory on EFS for future use..."
    mkdir -p $${EFS_MOUNT_POINT}/blockchain_data
fi

# Set up periodic sync from local to EFS (for master node only)
cat > /home/ubuntu/sync-blockchain-to-efs.sh << 'EOF'
#!/bin/bash
# This script syncs local blockchain data to EFS
# Should only run on one designated master node

LOCK_FILE="/tmp/efs-sync.lock"
EFS_MOUNT="/mnt/efs/blockchain_data"
LOCAL_DB="/home/ubuntu/.chia/mainnet/db"

# Check if we should sync (only if we're the master)
if [ -f "/etc/chia-master-node" ]; then
    # Use flock to ensure only one sync process runs
    (
        flock -n 200 || exit 1
        echo "Starting blockchain sync to EFS..."
        rsync -av --inplace $${LOCAL_DB}/* $${EFS_MOUNT}/
        echo "Blockchain sync completed at $(date)"
    ) 200>$${LOCK_FILE}
fi
EOF

chmod +x /home/ubuntu/sync-blockchain-to-efs.sh
chown ubuntu:ubuntu /home/ubuntu/sync-blockchain-to-efs.sh

# Add cron job for periodic sync (every 6 hours)
echo "0 */6 * * * ubuntu /home/ubuntu/sync-blockchain-to-efs.sh >> /var/log/chia-efs-sync.log 2>&1" | tee -a /etc/crontab

# Configure CloudWatch logs
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ubuntu/.chia/mainnet/log/debug.log",
            "log_group_name": "/aws/ec2/chia/${project_name}-${environment}",
            "log_stream_name": "{instance_id}-chia-debug",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/chia/${project_name}-${environment}",
            "log_stream_name": "{instance_id}-user-data",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/chia-efs-sync.log",
            "log_group_name": "/aws/ec2/chia/${project_name}-${environment}",
            "log_stream_name": "{instance_id}-efs-sync",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "ChiaNode",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_USAGE_IDLE",
            "unit": "Percent"
          },
          {
            "name": "cpu_usage_iowait",
            "rename": "CPU_USAGE_IOWAIT",
            "unit": "Percent"
          },
          "cpu_time_guest"
        ],
        "totalcpu": false,
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create systemd service for Chia
cat > /etc/systemd/system/chia-node.service << EOF
[Unit]
Description=Chia Full Node
After=network.target

[Service]
Type=forking
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/chia-blockchain
ExecStart=/home/ubuntu/chia-blockchain/venv/bin/chia start node
ExecStop=/home/ubuntu/chia-blockchain/venv/bin/chia stop node
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Chia service
systemctl daemon-reload
systemctl enable chia-node.service
systemctl start chia-node.service

# Wait for service to start
sleep 10

# Check node status
sudo -u ubuntu /home/ubuntu/chia-blockchain/venv/bin/chia show -s

echo "Chia node initialization completed!"

# Send completion signal
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
aws ec2 create-tags --region ${aws_region} --resources $${INSTANCE_ID} --tags Key=ChiaNodeStatus,Value=Ready

# Create a health check endpoint
cat > /home/ubuntu/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for load balancer

# Check if Chia node is running
if systemctl is-active --quiet chia-node.service; then
    # Check if node is synced (you may want to adjust this logic)
    SYNC_STATUS=$(/home/ubuntu/chia-blockchain/venv/bin/chia show -s | grep -i "sync" || true)
    if [[ $${SYNC_STATUS} == *"Synced"* ]] || [[ $${SYNC_STATUS} == *"Syncing"* ]]; then
        echo "OK"
        exit 0
    fi
fi

echo "UNHEALTHY"
exit 1
EOF

chmod +x /home/ubuntu/health-check.sh
chown ubuntu:ubuntu /home/ubuntu/health-check.sh

# Set up simple HTTP health check server (optional, for ALB health checks)
cat > /home/ubuntu/health-server.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import http.server
import socketserver

class HealthCheckHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            result = subprocess.run(['/home/ubuntu/health-check.sh'], capture_output=True, text=True)
            if result.returncode == 0:
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK')
            else:
                self.send_response(503)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'Service Unavailable')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress access logs

PORT = 8080
with socketserver.TCPServer(("", PORT), HealthCheckHandler) as httpd:
    httpd.serve_forever()
EOF

chmod +x /home/ubuntu/health-server.py
chown ubuntu:ubuntu /home/ubuntu/health-server.py

# Create systemd service for health check server
cat > /etc/systemd/system/chia-health-check.service << EOF
[Unit]
Description=Chia Health Check Server
After=network.target chia-node.service

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/bin/python3 /home/ubuntu/health-server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable chia-health-check.service
systemctl start chia-health-check.service

echo "User data script execution completed!"