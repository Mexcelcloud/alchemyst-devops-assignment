mkdir -p terraform/user_data

cat > terraform/user_data/gateway.sh << 'EOF'
#!/bin/bash
apt-get update -y
apt-get install -y nginx

# We'll update this config after we know the caller VM's private IP
# For now install nginx and enable it
systemctl enable nginx
systemctl start nginx
EOF