variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "minio_password" {
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