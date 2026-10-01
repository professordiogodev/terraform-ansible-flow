# Terraform + Ansible flow (load balancer version)

Terraform creates the infrastructure in AWS (`us-east-1`), then Ansible configures the machines.

> This is the **load-balancer** branch. For the simpler version (just 3 instances, no load balancer), use the `main` branch.

## What gets created

- A new VPC with 3 public subnets (one per AZ: `us-east-1a`, `b`, `c`) + internet gateway + route table
- 3 EC2 instances (`a`, `b`, `c`), one in each subnet
- An Application Load Balancer (ALB) that spreads HTTP traffic across the 3 instances
- An SSH key pair. The private key is saved straight into `ansible/<student_name>-ssh-key.pem`

Terraform also writes the files Ansible needs, so you don't have to copy anything by hand:
- `ansible/inventory.ini`: the 3 hosts with their public IPs and SSH key
- `ansible/group_vars/all.yml`: the ALB DNS name and the instances' IPs

## Folder structure

```
infra/     -> Terraform code (run terraform here)
ansible/   -> Ansible config, playbooks and roles (run ansible here)
```

## Getting started

Requirements: Terraform, Ansible and AWS credentials configured (`aws sts get-caller-identity` should work).

### 1. Create the infrastructure

```bash
cd infra
terraform init
terraform apply -var student_name=yourname
```

Use your own `student_name` (lowercase, short, no spaces). It's used to name the AWS resources, so it must be unique in the shared account.

When it finishes, Terraform prints the instances' public IPs and the ALB DNS name.

### 2. Configure the machines with Ansible

Wait about a minute for the instances to boot, then:

```bash
cd ../ansible
ansible all -m ping                    # check that Ansible can reach the 3 machines
ansible-playbook render-template.yaml  # install Nginx and deploy a custom index.html
ansible-playbook ping.yml              # call the ALB and print the instances' IPs
```

Each machine gets its own page using the `username` in `ansible/host_vars/<host>.yml`.

### 3. Test the load balancer

```bash
curl http://$(terraform -chdir=../infra output -raw alb_dns)
```

Run it a few times. The ALB answers from a different machine each time ("Hello from Alberta / Bocahontas / Cocoon").

### 4. Clean up

```bash
cd ../infra
terraform destroy -var student_name=yourname
```

![alt text](image-1.png)
