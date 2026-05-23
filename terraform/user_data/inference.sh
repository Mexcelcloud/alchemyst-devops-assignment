#!/bin/bash
set -e
apt-get update -y
apt-get install -y curl git jq docker.io
systemctl enable docker
systemctl start docker
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
export PATH="/root/.local/bin:$PATH"
echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc
cd /opt
git clone https://github.com/Alchemyst-ai/hiring.git
sleep 30
cat > /etc/systemd/system/inference-worker.service << SERVICE
[Unit]
Description=iii Inference Worker
After=network.target

[Service]
User=root
WorkingDirectory=/opt/hiring/may-2026/devops/quickstart
ExecStart=/root/.local/bin/iii worker start inference-worker
Restart=always
RestartSec=15
Environment=PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=III_ENGINE_URL=ws://${engine_ip}:49134

[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable inference-worker
systemctl start inference-worker