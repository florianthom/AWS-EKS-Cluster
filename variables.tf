#define variables
variable "server_port_http" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "availability-zone" {
  description = "AWS primary availability-zone"
  type        = string
  default     = "a"
}

variable "jumphost-private-ip" {
  description = "private internal ip of jumphost"
  type = string
  default = "10.0.1.10"
}

# for eks we need 2 subnets, each in a different az
# this is the second one
variable "availability-zone_second" {
  description = "AWS secondary availability-zone"
  type        = string
  default     = "b"
}

variable "bucketname" {
  description = "Name of the s3-bucket"
  type        = string
  default     = "s3-0"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "personal-website-eks-cluster-0"
}

output "eip-jumphost" {
  value       = aws_eip.eip_jumphost.public_ip
  description = "The public IP of the eip"
}

output "eip-kubernetes-ingress" {
  value        = aws_eip.eip_kubernetes_ingress.public_ip
  description = "The public IP of the eip"
}