# Distributed Inferencing Prototype — DevOps Deployment

**Candidate:** Dennis Sunday Chimezie (MexcelCloud)  
**Assignment:** Alchemyst AI DevOps Internship — May 2026  
**Repo:** https://github.com/mexcelcloud/alchemyst-devops-assignment

---

## Architecture Overview
🌍 PUBLIC INTERNET
                       │
                ┌──────▼──────┐
                │ gateway-vm  │  Public IP: 44.192.58.125
                │ NGINX :80   │  Subnet: 10.0.1.0/24
                └──────┬──────┘
                       │ proxy_pass
      ═══════════════════════════════════
      🔒  PRIVATE SUBNET (10.0.2.0/24)
      ═══════════════════════════════════
                ┌──────▼──────┐
                │  engine-vm  │  10.0.2.8
                │ iii engine  │  Ports: 3111 (API), 49134 (WS)
                │ + workers   │
                └─────────────┘
                ### Infrastructure Components

| Component | Type | IP | Purpose |
|---|---|---|---|
| gateway-vm | EC2 t3.micro | 44.192.58.125 (public) | NGINX reverse proxy |
| engine-vm | EC2 t3.micro | 10.0.2.8 (private) | iii engine + workers |
| inference-vm | EC2 t3.micro | 10.0.2.140 (private) | Python inference worker |
| caller-vm | EC2 t3.micro | 10.0.2.45 (private) | TypeScript caller worker |

---

## Infrastructure as Code

All infrastructure is provisioned via Terraform:

```bash
cd terraform
terraform init
terraform apply
```

### Resources Created
- VPC (10.0.0.0/16) with DNS enabled
- Public subnet (10.0.1.0/24) + Private subnet (10.0.2.0/24)
- Internet Gateway + NAT Gateway
- Security Groups (gateway-sg, private-workers-sg)
- 4 EC2 instances (Ubuntu 22.04)

---

## Deployment

### Prerequisites
- AWS CLI configured
- Terraform installed
- SSH key pair: `alchemyst-key`

### Step 1 — Provision Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### Step 2 — Deploy Engine VM
```bash
ssh -i ~/.ssh/alchemyst-key.pem ubuntu@<gateway-ip>
ssh -i ~/.ssh/alchemyst-key.pem ubuntu@10.0.2.8

# Install dependencies
sudo apt-get update -y
sudo apt-get install -y curl git jq docker.io nodejs npm python3 python3-pip
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
export PATH="/home/ubuntu/.local/bin:$PATH"

# Clone and configure
cd /opt && sudo git clone https://github.com/Alchemyst-ai/hiring.git
sudo chown -R ubuntu:ubuntu /opt/hiring
cd hiring/may-2026/devops/quickstart
sed -i 's|/Users/anuran/Alchemyst/hiring/may-2026/devops/quickstart|/opt/hiring/may-2026/devops/quickstart|g' config.yaml
sed -i 's/      host: 127.0.0.1/      host: 0.0.0.0/' config.yaml

# Install worker dependencies
pip3 install iii-sdk==0.11.0 watchfiles transformers torch gguf accelerate
cd workers/caller-worker && npm install && cd ../..

# Start engine
iii --config config.yaml
```

### Step 3 — Configure Gateway
```bash
ssh -i ~/.ssh/alchemyst-key.pem ubuntu@<gateway-ip>
sudo bash -c 'cat > /etc/nginx/sites-available/alchemyst << EOF
server {
    listen 80;
    location / {
        proxy_pass http://10.0.2.8:3111;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF'
sudo ln -s /etc/nginx/sites-available/alchemyst /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

---

## API Usage

### Endpoint
### Request
```json
{
  "messages": [
    {"role": "user", "content": "What is 2 + 2?"}
  ]
}
```

### Expected Response
```json
{
  "result": {
    "response": "2 + 2 equals 4.",
    "success": "You've connected two workers..."
  }
}
```

---

## Technical Challenges & Decisions

### KVM Unavailability on t3.micro
The iii framework uses VM sandboxing for worker isolation which requires KVM. EC2 t3 instances don't support nested virtualization. 

**Decision:** Ran workers directly on the engine VM without VM sandboxing. In production I would use:
- AWS bare metal instances (c5.metal) for KVM support
- Or switch sandbox runtime to Docker mode

### Network Isolation
Workers in the private subnet (10.0.2.0/24) have no public IP and are unreachable from the internet. Only the gateway VM accepts public traffic on port 80 and proxies to the engine's API on port 3111.

---

## Production Hardening (What I'd Add)

1. **TLS/HTTPS** — SSL certificate on gateway via Let's Encrypt/ACM
2. **Tighter Security Groups** — Restrict SSH to specific IP, not 0.0.0.0/0
3. **IAM Roles** — Instance profiles instead of user credentials
4. **CloudWatch** — Logging and alerting for all VMs
5. **Auto Scaling** — Multiple inference workers behind a load balancer
6. **Secrets Manager** — For any API keys or credentials

## Scaling for 100x Larger Model

1. **GPU instances** — g4dn.xlarge or p3.2xlarge for inference
2. **Model quantization** — GGUF Q4 instead of Q8 to reduce memory
3. **S3 model storage** — Mount model at startup instead of baking into instance
4. **Inference caching** — Redis layer for repeated queries
5. **Horizontal scaling** — Multiple inference workers behind ALB

---

## Infrastructure Teardown

To avoid ongoing AWS costs:
```bash
cd terraform
terraform destroy
