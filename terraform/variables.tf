variable "aws_region" {
  default = "ap-northeast-1"
}

variable "github_repository_url" {
  description = "GitHub repository URL (e.g., https://github.com/username/repo)"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for bastion server"
  type        = string
}
