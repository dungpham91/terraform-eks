terraform {
  backend "s3" {
    bucket         = "eks-cluster-s3-backend"
    key            = "eks-cluster"
    region         = "ap-southeast-1"
    encrypt        = true
    role_arn       = "arn:aws:iam::952429021322:role/Eks-ClusterS3BackendRole"
    dynamodb_table = "eks-cluster-s3-backend"
  }
}