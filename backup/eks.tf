# eks
# curl -LO https://dl.k8s.io/release/v1.18.0/bin/linux/amd64/kubectl
# aws eks --region "eu-central-1" update-kubeconfig --name "test-eks-cluster-1"
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

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "test-eks-cluster-1"
}


# route-table to route private subnet to public subnet by natting
resource "aws_route_table" "rt_eks_private_dev_main" {
  vpc_id = aws_vpc.vpc_dev_main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name          = "eks private subnet rt"
    "environment" = "development"
  }
}


# subnets
# tags are important, see
# https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
# https://github.com/kubernetes/kubernetes/issues/29298#issuecomment-356826381
resource "aws_subnet" "eks-subnet-1_private_dev_main" {
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

resource "aws_route_table_association" "rt-association_private_subnet_eks_1_dev_main" {
  subnet_id      = aws_subnet.eks-subnet-1_private_dev_main.id
  route_table_id = aws_route_table.rt_eks_private_dev_main.id
}

resource "aws_subnet" "eks-subnet-2_private_dev_main" {
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
  subnet_id      = aws_subnet.eks-subnet-2_private_dev_main.id
  route_table_id = aws_route_table.rt_eks_private_dev_main.id
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
    subnet_ids         = [aws_subnet.eks-subnet-1_private_dev_main.id, aws_subnet.eks-subnet-2_private_dev_main.id]
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

resource "aws_security_group_rule" "main-node-ingress-self" {
  type              = "ingress"
  description       = "Allow node to communicate with each other"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.main-node.id
  to_port           = 65535
  cidr_blocks = [
    "10.0.0.0/16",
    "172.16.0.0/12",
    "192.168.0.0/16",
  ]
}

### somehow not needed, since above sg-rule allows traffic ingress from all internal
### traffic, but actually there should be specified only the worker specific subnets
### and maybe this current general setting is changed to the more specify setting in the
### furture, so this rule is written because of this reason
resource "aws_security_group_rule" "main-node-ingress-cluster" {
  type              = "ingress"
  description       = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port         = 1025
  protocol          = "tcp"
  security_group_id = aws_security_group.main-node.id
  # docu: (Optional) The security group id to allow access to/from, depending on the type. Cannot be specified with cidr_blocks and self
  source_security_group_id = aws_security_group.sg-eks.id
  to_port                  = 65535
}

## setup launch-template
resource "aws_launch_template" "eks_launch_template" {
  name = "eks_launch_template"

  vpc_security_group_ids = [aws_security_group.main-node.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }

  # has to be specified, else no connection to cluster
  # how to get?
  #   - https://docs.aws.amazon.com/de_de/eks/latest/userguide/retrieve-ami-id.html
  #   - https://docs.aws.amazon.com/de_de/eks/latest/userguide/eks-optimized-ami.html
  # aws ssm get-parameter --name /aws/service/eks/optimized-ami/1.18/amazon-linux-2/recommended/image_id --region "eu-central-1" --query "Parameter.Value" --output text
  image_id      = "ami-0a3d7ac8c4302b317"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ssh.key_name
  user_data = base64encode(<<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
/etc/eks/bootstrap.sh --apiserver-endpoint "${aws_eks_cluster.main.endpoint}" --use-max-pods false "${var.cluster_name}"

--==BOUNDARY==--
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "EKS-MANAGED-NODE"
    }
  }
}
#  --b64-cluster-ca "${aws_eks_cluster.main.certificate_authority}" 

# setup nodegroup with explicit launch-configuration to get access to the userdata-attribut to change bootstrap options
resource "aws_eks_node_group" "demo" {
  cluster_name    = var.cluster_name
  node_group_name = "demo-group-1"
  node_role_arn   = aws_iam_role.main-node.arn
  subnet_ids      = [aws_subnet.eks-subnet-1_private_dev_main.id, aws_subnet.eks-subnet-2_private_dev_main.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  launch_template {
    name    = aws_launch_template.eks_launch_template.name
    version = aws_launch_template.eks_launch_template.latest_version
  }


  depends_on = [
    aws_iam_role_policy_attachment.main-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.main-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.main-node-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.main-node-AmazonEC2FullAccess,
    # aws_iam_role_policy_attachment.main-node-alb-ingress_policy,
    aws_launch_template.eks_launch_template,
    aws_eks_cluster.main
  ]

  tags = {
    Name = "eks-node-group-1"
  }
}



data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.main.token
}
