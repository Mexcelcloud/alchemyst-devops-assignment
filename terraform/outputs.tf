cat > terraform/outputs.tf << 'EOF'
output "gateway_public_ip" {
  value       = aws_instance.gateway.public_ip
  description = "Send curl requests to this IP"
}

output "engine_private_ip" {
  value       = aws_instance.engine.private_ip
  description = "iii engine private IP"
}

output "inference_private_ip" {
  value       = aws_instance.inference.private_ip
  description = "Python inference worker private IP"
}

output "caller_private_ip" {
  value       = aws_instance.caller.private_ip
  description = "TypeScript caller worker private IP"
}
EOF