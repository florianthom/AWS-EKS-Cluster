# AWS-Cluster-PW
This repository represents an attempt to create a cluster based on the eks-service of the aws-cloud. This cluster was intended to be used as a plattform for my personal-website (pw). This cluster was build up via the infrastructure-as-code approach (terraform). The code has very little requirements. So, it contains almost all needed parts for a cluster on its own: ssh-key-generation, creation of several admins, creation of vpc with several subnets with several hosts (including a host intended as a bastion-host), s3 blog-storage and s3-vpc-endpoint for it, eks-hosts and the corresponding eks-vpc-endpoint in addition with a good amount of secruity policies. A general grafical overview is given below.
Unfortunately i decided to stop working on this aws-approach. The reasons will be described below.

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

 - run terraform
```
 terraform apply
```

 - configure kubectl according the created cluster / setup connection between kubectl and cluster
```
 aws eks --region "eu-central-1" update-kubeconfig --name "test-eks-cluster-1"
```

 - save ssh-key to a known-directory for later usage (with this key you can connect to the jumphost/bastionhost + to all other machines inside the given vpc)
```
 terraform output ssh_private_key_pem > ../keys/sshKey/ssh-key.pem
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

 - list all pods across the kubernetes-namespaces
```
 kubectl get pods --all-namespaces -o wide
```

 - start testing ubuntu-pod
```
 kubectl run my-shell --rm -i --tty --image ubuntu -- bash
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

## Known issues with the given code
The intended infrastructure has no issures i guess. But the code, which is used to build up the infrastructure and therefore the actual infrastructure which is created has a major drawback. Jumphost works, worker works, the eks works somehow also. But if you want to run an additional e.g. test-ubuntu-pod, this pod will not receive an ip and therefore you get no shell into the pod. The problem is known. If you deploy the cluster via web-interface with the created secruity-group, launch-template and all that is works... Maybe there is some tagging missing (aws-eks requires specific tagging of the worker which is not done here). Or if you install calico it works also. But if you bootstrap the cluster as it is, there will be no ip for new pods.

## Why not continued?
In the past i chose the aws cloud mainly because i thought that it is the most popular one and i can expect a good amount of support for the usage of the aws-cloud. And that was right in general. I could read a lot of documentation, either from aws itself or from some blogs. So far so good. My main goal was to use kubernetes and it seemed that eks is a good option. I knew, i the optionion of others, there are better options for that like the gke, but i also thought about the aws-ecosystem. I wanted to use kubernetes, but i also wanted to be in the aws ecosystem. So i was willing to pay the price, so pay (money and possible less good kubernetes support) not only for kubernetes but also for the ecosystem. But in the end i experienced one really major drawback of eks. 
In short: the default eks-kubernetes-cni (aws-cni) and therefore the amount of ip-adresses is really "not so good".
The long version: In aws-eks you get the control-plane provided. And with it a default kubernetes-pod-cni. The kubernetes-cni is responsible to provide a ip for each pod, so that pods can communicate with each other. The default cni does that by taking "real" ips of the subnet (no overlay network) and assigning them to the pods. So the question become: How many ips can the "real" host (ec2-instance) receive. The answer to this question is provided by aws itself with the following formular: "# of ENI * (# of IPv4 per ENI - 1) + 2" - so number of elastic-network-interfaces * (number of ipv4 per eni -1) +2. Example t3.micro: 2*(2-1)+2 = 4. That means that my node with around 1gb ram and a maybe small but nethertheless good amount of cpu can only hold 4 pods. It does not mapper if that pod is cpu-heavy or chilling all the time. In my optionion that is barly acceptable. I mean you pay for the whole instance but you can only compute 4 parrallel pods with it because aws configured it that way? You pay for you "compute-freedom" (you can do what you want) but you can restricted by aws although your instance is around 0% utilized? I dont know...
Obvious solution: buy ec2 with more hardware. But do you want to buy more hardware although your instance is around 0% utilized?
Second, more complex workaround: Introduce a custom cni which is not supported from aws. A great example for this is calico-cni. You can see that i installed it successfully. But there is also a problem. In a nutshell: aws creates the controle plan of kubernetes for you in a aws-managed vpc. To connect this vpc to your individuell vpc aws created also a/several entry/entries within a for you untouchable routing-table with the routes to your subnet, e.g. 10.0.3.0/24. With calico you get introduced to a overlay network (so its possible many ips per node) e.g. in the cidr-range of 192.168.0.0/24. So if your pod know wants to communicate with your managed kubernetes-api-server (of eks), eks dont know how to route that traffic since 192.168.0.0/24 was not specified while creating eks-control-plan. This problem is describe [here](https://medium.com/faun/choosing-your-cni-with-aws-eks-vpc-cni-or-calico-1ee6229297c5) with more details. Mostly there is no need for a pod to communicate with your k8s-api-server, expect if you use istio. But for example kubernetes-metrics needs a connection. A next workaround for this is to specify network: host inside of the metrics-server-deployment, so that this pod communicated via the ip of the underlying node with the k8s-api-server. So the question is which services/pods needs with workaround too? I dont know... Maybe you pod will run, maybe not :). I mean somehow you can guess it by checking if your pod needs to communicate with the k8s-api-server, but do you like to think about that everytime you launch a new pod?
Inside of the second workaround (integration of calico) you could maybe configure calico in that way that it uses the cidr of your eks-worker-nodes-subnet. But in that case you have to be sure that your nodegroup dont assignes a private ip to a maybe new spawning node which is already beeing used by a pod. And in general, would you like to share a cidr-range across your pods and worker-node? I dont know...
In general there are aws-github-issues open regarding that topic in general.
In the end you have to choose between limitation by default-aws-eks-cni and the extra-work to introduce a custom cni + uncertainty with the connection. In short you have to choose between "not good" and "not good". Thats the main reason i stopped working with this project.


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
