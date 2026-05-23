data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.gateway.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/user_data/gateway.sh")
  tags = { Name = "gateway-vm" }
}

resource "aws_instance" "engine" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_workers.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/user_data/engine.sh")
  tags = { Name = "engine-vm" }
}

resource "aws_instance" "inference" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_workers.id]
  key_name               = var.key_name
  user_data = templatefile("${path.module}/user_data/inference.sh", {
    engine_ip = aws_instance.engine.private_ip
  })
  tags = { Name = "inference-vm" }
}

resource "aws_instance" "caller" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_workers.id]
  key_name               = var.key_name
  user_data = templatefile("${path.module}/user_data/caller.sh", {
    engine_ip = aws_instance.engine.private_ip
  })
  tags = { Name = "caller-vm" }
}
