resource "aws_rds_cluster" "cluster" {
  cluster_identifier   = "${local.cluster_name}-rds-aurora"
  engine               = "aurora-mysql"
  engine_version       = "5.7.12"
  database_name        = "exampletestdb"
  db_subnet_group_name = "${aws_db_subnet_group.default.name}"
  vpc_security_group_ids = ["${aws_security_group.eks-rds.id}"]
  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  master_username      = "${var.cluster-rds-username}"
  master_password      = "${var.cluster-rds-password}"
  backup_retention_period = 5
  final_snapshot_identifier = "dev-rds-snapshot"
  skip_final_snapshot = "true"
  preferred_backup_window = "07:00-09:00"
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = 2
  identifier         = "aurora-cluster-example-kube-${count.index}"
  cluster_identifier = "${aws_rds_cluster.cluster.id}"
  instance_class     = "db.t2.medium"
  engine             = "aurora-mysql"
  engine_version     = "5.7.12"
  db_subnet_group_name = "${aws_db_subnet_group.default.name}"
}

resource "aws_db_parameter_group" "cluster" {
  name   = "rds-pg-example"
  family = "aurora-mysql5.7"

}


resource "aws_db_subnet_group" "default" {
  name       = "main-example-sg"
  subnet_ids      = ["${module.vpc.private_subnets}"]

  tags = {
    Name = "My DB subnet group"
  }
}



resource "local_file" "rds-external-name" {

  content = <<RDS
kind: Service
apiVersion: v1
metadata:
 name: rds
spec:
 type: ExternalName
 externalName: ${aws_rds_cluster.cluster.endpoint}
RDS
  filename = "rds-dns.yml"
}


resource "local_file" "rds-secrets" {

  content = <<RDSUSERNAME
apiVersion: v1
kind: Secret
metadata:
  name: rds
type: Opaque
stringData:
  username: ${var.cluster-rds-username}
  password: ${var.cluster-rds-password}
RDSUSERNAME
  filename = "rds-secrets.yml"
}
