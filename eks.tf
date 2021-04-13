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
resource "aws_subnet" "eks-subnet-0" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}${var.availability-zone}"
  map_public_ip_on_launch = var.public_ip
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    iac_environment                             = "development"
  }
}

resource "aws_route_table_association" "rt-association_eks_subnet_0" {
  subnet_id      = aws_subnet.eks-subnet-0.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}

resource "aws_subnet" "eks-subnet-1" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.region}${var.availability-zone_second}"
  map_public_ip_on_launch = var.public_ip
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    iac_environment                             = "development"
  }
}

resource "aws_route_table_association" "rt-association_private_subnet_eks_2_dev_main" {
  subnet_id      = aws_subnet.eks-subnet-1.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}

# control plane
## control plane main role
resource "aws_iam_role" "eks-main-role" {
  name               = "eks-main-role"
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
resource "aws_iam_role_policy_attachment" "main-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-main-role.name
}

resource "aws_iam_role_policy_attachment" "main-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-main-role.name
}

## eks secruity group
resource "aws_security_group" "sg-eks" {
  name        = "terraform-eks"
  description = "Cluster communication with worker nodes"
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
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks-main-role.arn

  vpc_config {
    security_group_ids = [aws_security_group.sg-eks.id]
    subnet_ids         = [aws_subnet.eks-subnet-0.id, aws_subnet.eks-subnet-1.id]
    # kubectl is accessable from outside
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.main-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.main-cluster-AmazonEKSServicePolicy,
  ]
}

# worker node setup
## worker worker-nodes-main-role
resource "aws_iam_role" "main-node" {
  name = "terraform-eks-main-node"

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
resource "aws_iam_role_policy_attachment" "main-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.main-node.name
}

resource "aws_iam_role_policy_attachment" "main-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.main-node.name
}

resource "aws_iam_role_policy_attachment" "main-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.main-node.name
}

resource "aws_iam_role_policy_attachment" "main-node-AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.main-node.name
}

# resource "aws_iam_role_policy_attachment" "main-node-alb-ingress_policy" {
#   policy_arn = aws_iam_policy.alb-ingress.arn
#   role       = aws_iam_role.main-node.name
# }


## setup instance profile since the launch-config takes a instance-profile and no role
resource "aws_iam_instance_profile" "main-node" {
  name = "terraform-eks-main"
  role = aws_iam_role.main-node.name
}

## specify workers firewall
resource "aws_security_group" "main-node" {
  name        = "terraform-eks-main-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.vpc_dev_main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eks_node_group" "eks-nodegroup-0" {
  cluster_name    = var.cluster_name
  node_group_name = "eks-node-group-0"
  node_role_arn   = aws_iam_role.main-node.arn
  subnet_ids      = [aws_subnet.eks-subnet-0.id, aws_subnet.eks-subnet-1.id]
  ami_type       = "AL2_x86_64"
  disk_size      = "20"
  instance_types = ["m5a.large"] # maybe without a (intel instead of amd) better
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
    Name = "eks-nodegroup-0"
  }
  depends_on = [
    aws_iam_role_policy_attachment.main-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.main-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.main-node-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.main-node-AmazonEC2FullAccess,
  ]
}