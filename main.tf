terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
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
  key_name = "ssh-key-terraform"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDYOK1+NO7ihTuhMItqdMSmi86YduoJEhz0sHlQVFmVztf1PZLavmgkxBUto9F1UC79YX7f1aQHHynMZRrVs2fIrKIqnRmoo39X28q7PlAR+584afgxsM0S9fnmY6YU/oqQp7jY53bd9AV0HzGe1z8agZMWYI3vHhPUIGZDGVBy86BtCDwh7Wrdn3k9qqXsW9IOQFAK9wAhRpCaGY4xmoSl0ULKGcuxJoJNfxAsULgVkUcTcZkflwRsFm9HZy6MQ81VENvcgr1aUmh2XFNJrQX3Xa/eDMQni7v7BEl1hLkFlx30aKF+uMEbb6rJ/jk972LPjsMB8hVklRsf2sPHCNjt flo@flo-laptop"
}

# create vpc
resource "aws_vpc" "vpc_dev_main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    iac_environment                             = "development"
  }
}



# create an gw for the vpc
resource "aws_internet_gateway" "gw_dev_main" {
  vpc_id = aws_vpc.vpc_dev_main.id
  tags = {
    "environment" = "development"
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
    Name          = "public subnet rt"
    "environment" = "development"
  }
}