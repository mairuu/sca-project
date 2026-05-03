variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_username" {
  type    = string
  default = "postgres"
}

variable "minio_password" {
  type      = string
  sensitive = true
}

variable "minio_root_user" {
  type    = string
  default = "minioadmin"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jenkins_password" {
  type      = string
  sensitive = true
}

variable "storage_class" {
  type    = string
  default = "standard"
}

variable "grafana_password" {
  type      = string
  sensitive = true
}

variable "dockerhub_username" {
  type      = string
  sensitive = true
}

variable "dockerhub_password" {
  type      = string
  sensitive = true
}

variable "builder_remote_fs" {
  type        = string
  description = "Remote filesystem path for Jenkins builder node"
  default     = "/home/jenkins/jenkins-agent"
}

variable "builder_host" {
  type        = string
  description = "IP/hostname of the SSH builder node"
}

variable "builder_username" {
  type        = string
  description = "SSH username for Jenkins to connect to the builder node"
  default     = "jenkins"
}

variable "builder_ssh_private_key" {
  type        = string
  description = "Private SSH key for Jenkins to connect to the builder node"
  sensitive   = true
}