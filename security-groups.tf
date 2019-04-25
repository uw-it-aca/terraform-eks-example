resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  description = "SG to be applied to all *nix machines"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
} 


resource "aws_security_group_rule" "rds-ingress" {
  description              = "Allow the EKS cluster to communicate with the RDS instances"
  from_port                = 3306
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.eks-rds.id}"
  source_security_group_id = "${aws_security_group.all_worker_mgmt.id}"
  to_port                  = 3306
  type                     = "ingress"
}

resource "aws_security_group" "eks-rds" {
  name        = "terraform-eks-${local.cluster_name}-rds-cluster"
  description = "Security group for the rds cluster for this eks cluster"
  vpc_id       = "${module.vpc.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "terraform-eks-demo-node",
     "kubernetes.io/cluster/${local.cluster_name}", "owned",
    )
  }"
}