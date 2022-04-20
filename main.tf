provider "aws" {
  region = "ap-southeast-1"
  profile = "default"
  shared_credentials_files = ["/home/dungpt/.aws/credentials"]
}

module "network" {
  source                              = "./modules/network"
  environment                         =  var.environment
  vpc_cidr                            =  var.vpc_cidr
  vpc_name                            =  var.vpc_name
  cluster_name                        =  var.cluster_name
  public_subnets_cidr                 =  var.public_subnets_cidr
  availability_zones_public           =  var.availability_zones_public
  private_subnets_cidr                =  var.private_subnets_cidr
  availability_zones_private          =  var.availability_zones_private
  cidr_block-nat_gw                   =  var.cidr_block-nat_gw
  cidr_block-internet_gw              =  var.cidr_block-internet_gw
}

module "eks" {
  source                              =  "./modules/eks"
  cluster_name                        =  var.cluster_name
  environment                         =  var.environment
  eks_node_group_instance_types       =  var.eks_node_group_instance_types
  private_subnets                     =  module.network.aws_subnets_private
  public_subnets                      =  module.network.aws_subnets_public
  fargate_namespace                   =  var.fargate_namespace
}

module "database" {
  source                              =  "./modules/database"
  secret_id                           =  var.secret_id
  identifier                          =  var.identifier
  allocated_storage                   =  var.allocated_storage
  storage_type                        =  var.storage_type
  engine                              =  var.engine
  engine_version                      =  var.engine_version
  instance_class                      =  var.instance_class
  database_name                       =  var.database_name
  environment                         =  var.environment
  vpc_id                              =  module.network.vpc_id
  private_subnets                     =  module.network.aws_subnets_private
}

module "efs" {
  source                              = "./modules/efs"
  vpc_id                              =  module.network.vpc_id
  private_subnets_cidr                =  var.private_subnets_cidr
  private_subnets                     =  module.network.aws_subnets_private
  cluster_id                          =  module.eks.cluster_id    
}

module "ghost" {
  source                              =  "./modules/ghost"
  cluster_id                          =  module.eks.cluster_id    
  vpc_id                              =  module.network.vpc_id
  cluster_name                        =  module.eks.cluster_name
  database_host                       =  module.database.db_host
  database_password                   =  module.database.db_password
  ghost_domain                        =  var.ghost_domain
  size_ghost_pvc                      =  var.size_ghost_pvc
}