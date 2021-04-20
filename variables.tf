variable "env" {
  description = "Current environment"
  type        = string
  default     = "production"
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
