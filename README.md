# Distributed Inferencing Prototype — DevOps Deployment Manual

**Candidate:** Sunday Chimezie (MexcelCloud)  
**Assignment:** Alchemyst AI DevOps Internship — May 2026  
**Repo:** https://github.com/Mexcelcloud/alchemyst-devops-assignment  
**Original App Repo:** https://github.com/Alchemyst-ai/hiring/tree/main/may-2026/devops/quickstart

---

## What This Project Does

This deploys a distributed AI inference system across AWS infrastructure.
A small language model (Gemma 3-270M) runs behind a worker mesh built
with the iii framework. Requests come in via HTTP, get routed through
two workers, and return an AI-generated response as JSON.

User → curl POST → NGINX Gateway → iii Engine → TypeScript Caller
→ Python Inference Worker → Gemma AI Model → response back
🌍 PUBLIC INTERNET
                       │
                ┌──────▼──────┐
                │ gateway-vm  │  44.192.58.125 (public IP)
                │  NGINX :80  │  Receives all HTTP traffic
                └──────┬──────┘
                       │ forwards to port 3111
      ════════════════════════════════════════
      🔒  PRIVATE SUBNET — no public access
      ════════════════════════════════════════
                ┌──────▼──────┐
                │  engine-vm  │  10.0.2.8
                │ iii engine  │  WebSocket: 49134
                │  REST API   │  HTTP API:  3111
                └──────┬──────┘
                routes via WebSocket
                ┌──────┴────────────┐
         ┌──────▼──────┐    ┌───────▼──────┐
         │inference-vm │    │  caller-vm   │
         │  10.0.2.140 │    │  10.0.2.45   │
         │Python/Gemma │    │  TypeScript  │
         └─────────────┘    └──────────────┘
         ### VM Summary

| VM | Subnet | IP | Role |
|---|---|---|---|
| gateway-vm | Public | 44.192.58.125 | NGINX reverse proxy |
| engine-vm | Private | 10.0.2.8 | iii engine + workers |
| inference-vm | Private | 10.0.2.140 | Python/Gemma worker |
| caller-vm | Private | 10.0.2.45 | TypeScript HTTP worker |

---

## Prerequisites

Before you begin you need:

- AWS account with EC2, VPC, and IAM permissions
- AWS CLI installed and configured (`aws configure`)
- Terraform v1.5+ installed
- An SSH key pair (we create one in Step 1)
- WSL/Ubuntu or a Linux/Mac terminal

---

## Step 1 — Create SSH Key Pair

```bash
mkdir -p ~/.ssh

aws ec2 create-key-pair \
  --key-name alchemyst-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/alchemyst-key.pem

chmod 400 ~/.ssh/alchemyst-key.pem
```

Verify it exists in AWS:
```bash
aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output table
```

---

## Step 2 — Provision Infrastructure with Terraform

```bash
git clone https://github.com/Mexcelcloud/alchemyst-devops-assignment.git
cd alchemyst-devops-assignment/terraform

terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. Wait 5-10 minutes.

After completion note your outputs:
gateway_public_ip    = "xx.xx.xx.xx"
engine_private_ip    = "10.0.2.x"
inference_private_ip = "10.0.2.x"
caller_private_ip    = "10.0.2.x"
### What Terraform Creates
- VPC (10.0.0.0/16) with DNS enabled
- Public subnet (10.0.1.0/24) — gateway lives here
- Private subnet (10.0.2.0/24) — workers live here
- Internet Gateway — public subnet's door to the internet
- NAT Gateway — lets private VMs download packages
- Security group `gateway-sg` — allows port 80 and 22 from internet
- Security group `private-workers-sg` — allows all traffic within VPC only
- 4 EC2 instances (Ubuntu 22.04)

---

## Step 3 — Configure Gateway VM

SSH into the gateway:
```bash
ssh -i ~/.ssh/alchemyst-key.pem ubuntu@<gateway_public_ip>
```

Install and configure NGINX:
```bash
sudo apt-get update -y
sudo apt-get install -y nginx

sudo bash -c 'cat > /etc/nginx/sites-available/alchemyst << EOF
server {
    listen 80;
    location / {
        proxy_pass http://<engine_private_ip>:3111;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF'

sudo ln -s /etc/nginx/sites-available/alchemyst /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

Verify NGINX is running:
```bash
sudo systemctl status nginx
```

Exit the gateway:
```bash
exit
```

---

## Step 4 — Copy SSH Key to Gateway

This allows you to jump from gateway to private VMs:
```bash
scp -i ~/.ssh/alchemyst-key.pem \
  ~/.ssh/alchemyst-key.pem \
  ubuntu@<gateway_public_ip>:~/.ssh/

# SSH back to gateway and set permissions
ssh -i ~/.ssh/alchemyst-key.pem ubuntu@<gateway_public_ip>
chmod 400 ~/.ssh/alchemyst-key.pem
```

---

## Step 5 — Deploy Engine VM

From the gateway, SSH to the engine VM:
```bash
ssh -i ~/.ssh/alchemyst-key.pem ubuntu@<engine_private_ip>
```

Install dependencies:
```bash
sudo apt-get update -y
sudo apt-get install -y curl git jq docker.io python3 python3-pip

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install iii
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
export PATH="/home/ubuntu/.local/bin:$PATH"
echo 'export PATH="/home/ubuntu/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
iii --version
```

Clone the app:
```bash
cd /opt
sudo git clone https://github.com/Alchemyst-ai/hiring.git
sudo chown -R ubuntu:ubuntu /opt/hiring
cd hiring/may-2026/devops/quickstart
```

Fix the hardcoded paths in config:
```bash
sed -i 's|/Users/anuran/Alchemyst/hiring/may-2026/devops/quickstart|/opt/hiring/may-2026/devops/quickstart|g' config.yaml
```

Fix the API host to listen on all interfaces:
```bash
sed -i 's/      host: 127.0.0.1/      host: 0.0.0.0/' config.yaml
```

Install worker dependencies:
```bash
# Python worker deps
pip3 install iii-sdk==0.11.0 watchfiles transformers torch gguf accelerate

# TypeScript worker deps
cd workers/caller-worker
npm install
cd ../..
```

Start the engine:
```bash
iii --config config.yaml
```

You should see:
Engine listening on address: 0.0.0.0:49134
API listening on address: 0.0.0.0:3111

Leave this terminal running.

---

## Step 6 — Test the API

From your local machine:
```bash
curl -X POST http://<gateway_public_ip>/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages": [{"role": "user", "content": "What is 2 + 2?"}]}'
```

Expected response:
```json
{
  "result": {
    "response": "2 + 2 equals 4.",
    "success": "You've connected two workers and they're interoperating seamlessly."
  }
}
```

---

## Problems Encountered & How They Were Solved

### Problem 1 — Hardcoded Paths in config.yaml

**What happened:**
The cloned repo had the original author's machine path hardcoded:
/Users/anuran/Alchemyst/hiring/...

This caused the engine to fail when looking for workers.

**Fix:**
```bash
sed -i 's|/Users/anuran/...|/opt/hiring/...|g' config.yaml
```

**Lesson:** Always check config files for absolute paths when deploying someone else's code.

---

### Problem 2 — API Bound to localhost Only

**What happened:**
The iii engine's REST API was listening on `127.0.0.1:3111` by default. NGINX on the gateway could not reach it because it was only accessible locally on the engine VM.

**Fix:**
Changed `host: 127.0.0.1` to `host: 0.0.0.0` in config.yaml so the API accepts connections from any interface within the VPC.

---

### Problem 3 — KVM Not Available on EC2 t3.micro

**What happened:**
The iii framework sandboxes each worker inside a lightweight VM for isolation. Creating a VM requires KVM (Kernel-based Virtual Machine). EC2 t3 instances are themselves virtual machines and AWS does not allow nested virtualization on general-purpose instance types.

Error received: VM execution failed: KVM not available -- /dev/kvm does not exist.
**What was tried:**
- Switching sandbox to Docker mode in iii.worker.yaml
- Clearing iii cache and retrying
- Both approaches still resulted in the KVM error

**Where this got stuck:**
Workers could not start. The iii engine ran correctly but inference-worker and caller-worker failed at the sandbox preparation stage.

**Options to resolve:**

| Option | Cost | Effort | Notes |
|---|---|---|---|
| Use AWS metal instance (c5.metal) | ~$4/hr | Low | Just change instance_type in ec2.tf |
| Use DigitalOcean/Hetzner droplet | $4-6/mo | Medium | Full KVM support, much cheaper |
| Run workers without sandbox | Free | Low | Less isolation but works on any VM |
| Docker sandbox mode | Free | Medium | Needs further iii config investigation |

**Recommended fix for continuation:**

Change `instance_type` in `terraform/ec2.tf` for inference-vm:
```hcl
resource "aws_instance" "inference" {
  instance_type = "c5.metal"  # was t3.small
  ...
}
```

Or run workers directly without sandboxing by removing the
sandbox section from `workers/inference-worker/iii.worker.yaml`.

---

### Problem 4 — Disk Space on EC2 Instance

**What happened:**
Default EC2 root volume is 8GB. PyTorch alone is 532MB compressed,
expanding to ~2GB. Installation failed with: No space left on device

**Fix:**
Expanded EBS volume from 8GB to 20GB using AWS CLI:
```bash
aws ec2 modify-volume --volume-id <vol-id> --size 20
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

**Prevention:**
Set root volume size to 30GB in Terraform from the start:
```hcl
root_block_device {
  volume_size = 30
}
```

---

## Current Status

| Task | Status |
|---|---|
| VPC + subnets + security groups | ✅ Complete |
| 4 EC2 instances provisioned | ✅ Complete |
| NGINX gateway configured | ✅ Complete |
| iii engine running | ✅ Complete |
| Worker dependencies installed | ✅ Complete |
| inference-worker running | ❌ Blocked by KVM |
| caller-worker running | ❌ Blocked by KVM |
| End-to-end curl test | ❌ Pending worker fix |

---

## Production Hardening

1. **TLS/HTTPS** — Add SSL via AWS ACM + ALB in front of gateway
2. **Restrict SSH** — Change security group to specific IP, not 0.0.0.0/0
3. **IAM Roles** — Attach instance profiles instead of using user credentials
4. **CloudWatch** — Log groups and alarms for CPU, memory, errors
5. **Auto Scaling** — Multiple inference workers behind an ALB
6. **Secrets Manager** — Store any credentials securely

---

## Scaling for 100x Larger Model

1. **GPU instances** — g4dn.xlarge ($0.53/hr) for inference
2. **S3 model storage** — Store model in S3, mount at startup
3. **GGUF Q4 quantization** — Half the memory, minimal quality loss
4. **Redis caching** — Cache repeated inference queries
5. **SQS queue** — Async processing for long inference jobs
6. **Horizontal scaling** — Multiple inference workers behind ALB

---

## Teardown

To destroy all AWS resources and stop charges:
```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. All VMs, networking, and storage will be deleted.

> ⚠️ The NAT Gateway costs ~$0.045/hour even when idle. Always destroy when not in use.
