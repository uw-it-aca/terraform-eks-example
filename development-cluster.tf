variable "cluster-rds-username" {
  type = "string"
}

variable "cluster-rds-password" {
  type = "string"
}

variable "aws-account-id" {

}

locals {
  cluster_name = "uw-it-axdd-example"

  worker_groups = [
    {
      instance_type        = "m4.large"
      subnets              = "${join(",", module.vpc.private_subnets)}"
      asg_desired_capacity = "1"
      asg_min_size         = "1"
    },
  ]

  worker_groups_launch_template = [
    {
      instance_type                            = "m4.large"
      subnets                                  = "${join(",", module.vpc.private_subnets)}"
      additional_security_group_ids            = "${aws_security_group.worker_group_mgmt_one.id},${aws_security_group.worker_group_mgmt_two.id}"
      override_instance_type                   = "t2.large"
      asg_desired_capacity                     = "2"
      asg_min_size                             = "1"
      spot_instance_pools                      = 10
      on_demand_percentage_above_base_capacity = "0"
    },
  ]

  tags = {
    Environment = "dev"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
    Workspace   = "${terraform.workspace}"
  }
}


data "aws_availability_zones" "available" {}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "1.60.0"
  name               = "test-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["${data.aws_availability_zones.available.names[0]}", "${data.aws_availability_zones.available.names[1]}", "${data.aws_availability_zones.available.names[2]}"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  tags               = "${merge(local.tags, map("kubernetes.io/cluster/${local.cluster_name}", "shared"))}"
  enable_dns_hostnames = true 
}

module "dev-eks-cluster" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "3.0.0"
  cluster_name = "${local.cluster_name}"
  subnets      = ["${module.vpc.private_subnets}"]
  vpc_id       = "${module.vpc.vpc_id}"
  worker_groups                        = "${local.worker_groups}"
  worker_groups_launch_template        = "${local.worker_groups_launch_template}"
  worker_group_count                   = "1"
  worker_group_launch_template_count   = "1"
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  manage_aws_auth = "true"

  map_users = [
    
  ]

  map_users_count = 0
  map_roles = [
  ]

  map_roles_count = 0

  tags = {
    environment = "dev"
  }

  worker_additional_security_group_ids = ["${aws_security_group.all_worker_mgmt.id}"]
}
