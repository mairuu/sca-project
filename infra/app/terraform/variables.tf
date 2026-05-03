variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy (e.g. 1.0.0)"
}

variable "docker_hub_user" {
  type    = string
  default = "rhicien"
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "minio_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}
