terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.39.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.0.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.0.0"
    }

    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }

  required_version = "~> 0.14"
}

# specify provider
provider "aws" {
  region = var.region
}


resource "aws_key_pair" "ssh" {
  key_name   = "ssh-key-terraform"
  public_key = trimspace(file("${path.module}/secrets/public_key_florian.txt"))
}


# create vpc
resource "aws_vpc" "vpc_dev_main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    environment = var.env
  }
}



# create an gw for the vpc
resource "aws_internet_gateway" "gw_dev_main" {
  vpc_id = aws_vpc.vpc_dev_main.id
  tags = {
    environment = var.env
  }
}

# adds a routing table to the vpc (there is already a "main-routing-table")
#   one for public traffic
#   one for private traffic (actually not needed for now since main-routing-table exists)
resource "aws_route_table" "rt_public_dev_main" {
  vpc_id = aws_vpc.vpc_dev_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_dev_main.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw_dev_main.id
  }
  tags = {
    Name        = "public subnet rt"
    environment = var.env
  }
}
