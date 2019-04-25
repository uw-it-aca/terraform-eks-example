
resource "aws_codebuild_project" "dev-provisioner-codebuild" {
  name         = "${var.service-label}-dev-provisioner"
  description  = "${var.service-label}'s CodeBuild project for dev instance creation"
  build_timeout      = "15"
  service_role = "${aws_iam_role.dev-provisioner-role.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.dev-provisioner-cache.bucket}"
  }

  environment {
    compute_type = "BUILD_GENERAL1_LARGE"
    image        = "aws/codebuild/python:3.6.5"
    type         = "LINUX_CONTAINER"
    privileged_mode = "true"

    environment_variable {
      "name" = "REPO_NAME"
      "value" = "${var.repo-name}"
    }
    environment_variable {
      "name"  = "AWS_DEFAULT_REGION"
      "value" = "us-west-2"
    }

    environment_variable {
      "name" = "AWS_ACCOUNT_ID"
      "value" = "${var.aws-account-id}"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/uw-it-aca/${var.repo-name}"
    git_clone_depth = 1
    report_build_status = false
    buildspec   = <<CONTAINER_BUILDSPEC
version: 0.2
phases:
  install:
    commands:
      - IMAGE_TAG=$( git branch -a --contains $CODEBUILD_SOURCE_VERSION | sed '2p' --silent | tr -d " " | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed -e 's/\W/-/g')
      - RELEASE_NAME=$( echo "$REPO_NAME-dev-$IMAGE_TAG" | sed -e "s/[\W_]/-/g")
      - apt-get update
      - apt-get install apt-transport-https ca-certificates curl software-properties-common --assume-yes
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      - apt-get update
      - apt-get install docker-ce --assume-yes
      - git branch -a --contains $CODEBUILD_SOURCE_VERSION
      - echo $IMAGE_TAG
      - REPO_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
  pre_build:
    commands:
      - docker version
      - $(aws ecr get-login  --no-include-email)
      - docker pull $REPO_URL/${aws_ecr_repository.dev_provisioner_web.name}:$IMAGE_TAG || true
  build:
    commands:
      - docker build --cache-from  $REPO_URL/${aws_ecr_repository.dev_provisioner_web.name}:$IMAGE_TAG -t $REPO_URL/${aws_ecr_repository.dev_provisioner_web.name}:$IMAGE_TAG  .
  post_build:
    commands:
      - docker push $REPO_URL/${aws_ecr_repository.dev_provisioner_web.name}:$IMAGE_TAG
      - aws --version
      - curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/kubectl
      - chmod +x ./kubectl
      - mkdir $HOME/bin && cp ./kubectl $HOME/bin/kubectl
      - curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator
      - chmod +x ./aws-iam-authenticator
      - cp aws-iam-authenticator $HOME/bin/aws-iam-authenticator
      - export PATH=$HOME/bin:$PATH
      - aws-iam-authenticator init -i ${var.cluster-name} 
      - aws eks update-kubeconfig --name ${var.cluster-name}
      - curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
      - chmod 700 get_helm.sh
      - ./get_helm.sh
      - mkdir /helm
      - cd /helm
      - git clone http://github.com/uw-it-aca/django-development-chart
      - cd django-development-chart && git checkout develop && cd ..
      - helm init --service-account tiller --upgrade
      - helm delete $RELEASE_NAME --purge || true
      - helm install django-development-chart/ --name $RELEASE_NAME --set branch=$IMAGE_TAG,repo=$(echo $REPO_NAME | sed -e 's/[\W_]/-/g') --set-string aws_account=$AWS_ACCOUNT_ID
CONTAINER_BUILDSPEC
  }

}

resource "aws_codebuild_webhook" "dev-build-github-webhook" {
  project_name = "${aws_codebuild_project.dev-provisioner-codebuild.name}"
}

resource "aws_iam_role" "dev-provisioner-role" {
  name = "${var.service-label}-codebuild"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_s3_bucket" "dev-provisioner-cache" {
  bucket = "${var.service-label}-provisioner-cache"
  acl    = "private"
}


resource "aws_ecr_repository" "dev_provisioner_web" {
  name = "${var.service-label}-provisioner-web-ecr"
}

resource "aws_ecr_repository_policy" "dev_provisioner_ecr_policy" {
  repository = "${aws_ecr_repository.dev_provisioner_web.name}"

  policy = <<ECR_POLICY
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "ReadOnly",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
ECR_POLICY
}

resource "aws_iam_role_policy" "dev-provisioner-codebuild" {
  role        = "${aws_iam_role.dev-provisioner-role.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.dev-provisioner-cache.arn}",
        "${aws_s3_bucket.dev-provisioner-cache.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
POLICY
}


resource "local_file" "kubernetes-auth"{
  filename = "${var.repo-name}-auth.yml"
  content = <<AUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${var.repo-name}-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::872975797617:role/${aws_iam_role.dev-provisioner-role.name}
      username: admin
      groups:
        - system:masters
AUTH

}
