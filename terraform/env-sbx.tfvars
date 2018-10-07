region = "us-west-2"
project_name = "ecs-wl-ssl-gateway"
env = "sandbox"

ecs_cluster_name = "cluster_sbx"
ecs_service_role = "arn:aws:iam::IDCLIENTAWS:role/ECS_Service_SSLCerts_RO"
ecs_container_name = "lb_container"
ecs_app_min_capacity = 3
ecs_app_max_capacity = 10
ecs_service_autoscale = "arn:aws:iam::IDCLIENTAWS:role/ecsAutoscaleRole"

# Current Public Subnets IDs
# -----------------------------------
#
# PRD - ["subnet-1","subnet-2","subnet-3"]
# SBX - ["subnet-4","subnet-5","subnet-6"]
# STG - ["subnet-7","subnet-8","subnet-9"]
nlb_subnets = ["subnet-4","subnet-5","subnet-6"]

# Current VPC IDs
# -----------------------------------
#
# PRD - vpc-1
# SBX - vpc-2
# STG - vpc-3
nlb_vpc = "vpc-2"
