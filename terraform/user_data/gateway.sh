#!/bin/bash
apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/alchemyst << 'EOF'
server {
    listen 80;

    location / {
        proxy_pass http://10.0.2.45:3111;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/alchemyst /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx