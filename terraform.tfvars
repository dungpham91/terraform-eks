environment                  = "prod"
cluster_name                 =  "dungpham"
vpc_cidr                     =  "172.16.0.0/16"
vpc_name                     =  "main"
public_subnets_cidr          =  ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
private_subnets_cidr         =  ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
availability_zones_public    =  ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
availability_zones_private   =  ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
cidr_block-internet_gw       =  "0.0.0.0/0"
cidr_block-nat_gw            =  "0.0.0.0/0"
eks_node_group_instance_types=  "t2.micro"
fargate_namespace            =  "fargate-node"
secret_id                    =  "database"
identifier                   =  "database"
allocated_storage            =  10
storage_type                 =  "gp2"
engine                       =  "mysql"
engine_version               =  5.7
instance_class               =  "db.t2.micro"
database_name                =  "db"