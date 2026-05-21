cat > terraform/user_data/engine.sh << 'EOF'
#!/bin/bash
set -e

# Install dependencies
apt-get update -y
apt-get install -y curl git jq

# Install iii
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
export PATH="/root/.local/bin:$PATH"
echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc

# Clone repo
cd /opt
git clone https://github.com/Alchemyst-ai/hiring.git
cd hiring/may-2026/devops/quickstart

# Update config to use absolute paths
sed -i 's|/Users/anuran/Alchemyst/hiring/may-2026/devops/quickstart|/opt/hiring/may-2026/devops/quickstart|g' config.yaml

# Create systemd service
cat > /etc/systemd/system/iii-engine.service << 'SERVICE'
[Unit]
Description=iii Engine
After=network.target docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/opt/hiring/may-2026/devops/quickstart
ExecStart=/root/.local/bin/iii --config config.yaml
Restart=always
RestartSec=10
Environment=PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable iii-engine
systemctl start iii-engine
EOF