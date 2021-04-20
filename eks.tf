# eks
# curl -LO https://dl.k8s.io/release/v1.18.0/bin/linux/amd64/kubectl
# aws eks --region "eu-central-1" update-kubeconfig --name "personal-website-eks-cluster-0"
# ssh beachten: default user of amazon-eks-optimized-ami: ec2-user
# terraform output ssh_private_key_pem > ../keys/sshKey/ssh-key.pem
# check cni-version: kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2
# eks plattform version is listed in webconsole (here eks.3)

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster_name
}

variable "public_ip" {
  type        = bool
  description = "Indicates whether the subnets map public ips on instance-launches"
  default     = true
}

#subnets
# tags are important, see
# https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
# https://github.com/kubernetes/kubernetes/issues/29298#issuecomment-356826381
resource "aws_subnet" "eks_subnet_0" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}${var.availability-zone}"
  map_public_ip_on_launch = var.public_ip
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"           = "1"
  }
}

resource "aws_route_table_association" "rt-association_eks_subnet_0" {
  subnet_id      = aws_subnet.eks_subnet_0.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}

resource "aws_subnet" "eks_subnet_1" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}${var.availability-zone_second}"
  map_public_ip_on_launch = var.public_ip
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"           = "1"
  }
}

resource "aws_route_table_association" "rt-association_private_subnet_eks_2_dev_main" {
  subnet_id      = aws_subnet.eks_subnet_1.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}

# control plane
resource "aws_iam_role" "eks_iam_role_assume_role" {
  name               = "eks_iam_role_assume_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

## main-role policy-attachments
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role_assume_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_iam_role_assume_role.name
}

# This security group controls networking access to the Kubernetes masters.
# Needs to be configured also with an ingress rule to allow traffic from the worker nodes.
resource "aws_security_group" "eks_sg_control_plan_0" {
  name        = "eks_sg_control_plan_0"
  description = "Allow communication between control plane and workers"
  vpc_id      = aws_vpc.vpc_dev_main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "10.0.0.0/16",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

## create control plane
resource "aws_eks_cluster" "eks_control_plane" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_iam_role_assume_role.arn
  vpc_config {
    security_group_ids = [aws_security_group.eks_sg_control_plan_0.id]
    subnet_ids         = [aws_subnet.eks_subnet_0.id, aws_subnet.eks_subnet_1.id]
    # kubectl is accessable from outside
    endpoint_private_access = false
    endpoint_public_access  = true
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
  tags = {
    Name        = "eks_control_plane"
    environment = var.env
  }
}

# worker node setup
## worker worker-nodes-main-role
resource "aws_iam_role" "eks_iam_role_0" {
  name = "eks_iam_role_0"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

## policies for worker-nodes-main-role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_iam_role_0.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_iam_role_0.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_container_registry_readonly_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_iam_role_0.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_full_access_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.eks_iam_role_0.name
}

# resource "aws_iam_role_policy_attachment" "main-node-alb-ingress_policy" {
#   policy_arn = aws_iam_policy.alb-ingress.arn
#   role       = aws_iam_role.eks_iam_role_0.name
# }


# This security group controls networking access to the Kubernetes worker nodes.
resource "aws_security_group" "eks_sg_internode_communication_0" {
  name        = "eks_sg_nodes_0"
  description = "allow nodes to communicate with each other"
  vpc_id      = aws_vpc.vpc_dev_main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "allow nodes to communicate with each other"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eks_node_group" "eks_nodegroup_0" {
  cluster_name    = var.cluster_name
  node_group_name = "eks-node-group-0"
  node_role_arn   = aws_iam_role.eks_iam_role_0.arn
  subnet_ids      = [aws_subnet.eks_subnet_0.id, aws_subnet.eks_subnet_1.id]
  ami_type        = "AL2_x86_64"
  disk_size       = "20"
  # a = amd
  instance_types = ["m5a.large"]
  # ssh is open to the internet -> see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
  remote_access {
    ec2_ssh_key = aws_key_pair.ssh.key_name
  }
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  tags = {
    Name        = "eks_nodegroup_0"
    environment = var.env
  }
  depends_on = [
    aws_eks_cluster.eks_control_plane,
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ec2_container_registry_readonly_policy,
    aws_iam_role_policy_attachment.eks_ec2_full_access_policy,
  ]
}
