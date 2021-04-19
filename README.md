# AWS-Cluster-PW
This repository represents an attempt to create a cluster based on the eks-service of the aws-cloud. This cluster was intended to be used as a plattform for my personal-website (pw). This cluster was build up via the infrastructure-as-code approach (terraform). The code has very little requirements. So, it contains almost all needed parts for a cluster on its own: ssh-key-generation, creation of several admins, creation of vpc with several subnets with several hosts (including a host intended as a bastion-host), s3 blog-storage and s3-vpc-endpoint for it, eks-hosts and the corresponding eks-vpc-endpoint in addition with a good amount of secruity policies. A general grafical overview is given below.

![alt text](.github/images/infrastructure.png)


## Learned
 - cluster-infrastructure-components
 - cluster-networking
   - natting
   - subnetting
   - ingress, egress
 - aws-provider
   - iam
   - vpc
   - ec2
   - eks
   - autoscaling groups
   - nodegroups
   - launchtemplate
   - s3
   - aws-routing with several individual services
   - cloudtrail
   - cloudwatch
 - infrastructure-as-code
   - ansible
   - terraform
     - aws provider
     - aws modules like vpc and eks (later removed since actually not needed)
   - kubernetes provider
   - (packer)

## Prerequisites
 - aws-account (the account could/will be charged with the given infrastructure)
 - terraform
 - kubectl

## Getting Started
This "Getting Started" section describes a sequence of steps which are needed to setup the given infrastructure. The assumend current state is: fresh aws-root-account. The given steps are mostly non-optional and dont have to be in the correct order (but mostly are)
 - create admin-iam account and give him rights to change billing options (by utilizing the aws-graphical-web-console)
   - this user will be your new admin account (hence the billing option)
   - save the actual root-admin with 2-way-authentication e.g. microsoft-authenticator-app and hide the root-account credentials somewhere save
 - logout with root-account and login with iam-admin account
 - create aws-cli credentials for this account (still in web-interface)
 - store these credentials in environment-variables of your os (read by terraform at runtime)
 - download this repository and cd into it
 - run ./runTerraform.bash
 - the infrastructure should build up

## Important commands
This section describes important commands, mostly important for development purposes.

### general
 - lookup the max-number of pods you can use per node (with your instance type)
```
 # open url: https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt
 ```
 - connect to node in a private subnet (connection to a node you can only reach over the jumphost)
```
 # add the key-file to your ssh-config
 ssh-add <key-file>
 ssh -A ubuntu@ip-of-your-jumphost
 
 # pay attention: nodes for eks run unter the
 # eks-optimized-aws-linux2-image -> the default user is "ec2-user"
 # so e.g. ec2-user@ip-of-your-hidden-node
 ssh ubuntu@ip-of-your-hidden-node
 ```

### aws
 - configure kubectl according the created cluster / setup connection between kubectl and cluster
```
 aws eks --region "eu-central-1" update-kubeconfig --name "test-eks-cluster-1"
```

 - get current aws-cli-identity
```
aws sts get-caller-identity
```

### terraform
 - run terraform
```
 terraform apply
```

 - save ssh-key to a known-directory for later usage (with this key you can connect to the jumphost/bastionhost + to all other machines inside the given vpc)
```
 terraform output ssh_private_key_pem > ../keys/sshKey/ssh-key.pem
```

### kubernetes
#### kubernetes-general
- list all pods across the kubernetes-namespaces
```
 kubectl get pods --all-namespaces -o wide
```

 - start testing ubuntu-pod
```
 kubectl run my-shell --rm -i --tty --image ubuntu -- bash
```
#### kubernetes-ingress
keep in mind that the ingress is programmed to listen for a specific domain (according to the ingress-resource) (e.g. florianthom.io). So as long es you dont searched for florianthom.io you get "nginx not found". Important since you have the external ip of the ingress and you are maybe tempted to try it out but this wont work.
Dns "a record" required for ingress-nginx: Mapping from ip to external-ip of ingress ("external-ip" is an dns-aws-name -> you have to dnslookup the ip).
How to install: https://kubernetes.github.io/ingress-nginx/deploy/#aws .

 - get ingress controller (/check if installed/running)
```
kubectl get pods -n ingress-nginx
```

 - get ingress ressource (!= controller)
```
kubectl get ingress
```

 - get external "ip" (actually domain-name) to attach the real dns to (on cloudflare or similar)
```
kubectl get services -n ingress-nginx
```

## Additional optional related commands
 - install ingress-nginx-controller
```
# https://kubernetes.github.io/ingress-nginx/deploy/#aws
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.45.0/deploy/static/provider/aws/deploy.yaml
```

 - install metrics-server
```
 kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

 - install calico-cni (should be happen before nodegroup-creation)
   - the current code builds up all elements, including nodegroups, so this can only take place after nodegroup-creation with the given codebase
```
 kubectl delete daemonset -n kube-system aws-node
 kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

 - restart ec2 instances (if calico is installed after nodegroup-creation)
```
 # go into aws web-interface and delete all ec2-instances of the eks-nodegroup
 # the nodegroup will spawn new ec2-instances, which will now schedule pods with calico ip
 # calico ip is in the cidr-range of something like 192.168.x.x/24
```




 




## Filestructure
In general a kind of domain-driven-design was chosen. So there is a
 - main.tf File: describes mostly shared ressources: e.g. main-public-route-table, eip, ssh-key-creation, ...
 - jumphost.tf: describes the jumphost / bastionhost (and its related ressources)
 - worker.tf: describes the worker-host (independend of eks)
 - eks.tf: describes all ressources needed for eks
 - *.backup.tf: describes old states of files


## Monthly costs
The very granular cost-approximation of the given infrastructure is somewhere around 150€-200€
 - nat (needed for private subnets): 0.052 per hour -> around 40€ (according to hour-pricing not GB-wise)
 - aws-eks control-plane: 0.10€ per hour (around 80€ per month)
 - actual ec2 worker (3: jumphost, independend worker, eks-worker) (instance: t3.micro): 0.012€ per hour -> 3 worker: 3* 0.012 = 0.036€ per hour -> 0.036*24h*30d = ca 26€
 - more (vpc, s3, cloudtrail, ...): idk around maybe 5€

## Build with
 - terraform v0.13
 - eks (Kubernetes v18)



## Acknowledgements
 - overall aws integration: https://www.youtube.com/watch?v=NjYsXuSBZ5U&ab_channel=SanjeevThiyagarajan
 - eks in general: https://medium.com/risertech/production-eks-with-terraform-5ad9e76db425
 - nat: https://dev.betterdoc.org/infrastructure/2020/02/04/setting-up-a-nat-gateway-on-aws-using-terraform.html
 - introduction to calico: https://luktom.net/en/e1715-how-to-and-why-replace-aws-cni-with-calico-on-aws-eks-cluster
 - eks-default-cni vs eks-custom-cni: https://medium.com/faun/choosing-your-cni-with-aws-eks-vpc-cni-or-calico-1ee6229297c5
 - additional sources: additionalInformations.pdf (unfortunatly notes are mostly in german-lenguage)
