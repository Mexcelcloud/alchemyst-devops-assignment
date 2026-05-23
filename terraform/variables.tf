variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  description = "Your AWS EC2 key pair name"
  type        = string
  default     = "alchemyst-key"
}