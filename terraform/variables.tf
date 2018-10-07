provider "aws" {
  region     = "us-west-2"
}

variable "region" {
  description = "AWS region to deploy"
}

variable "project_name" {
  description = "Main name of the project"
}

variable "env" {
  description = "Environment to deploy (Remember to checking the nlb_subnets and nlb_vpc variables)"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
}

variable "ecs_service_role" {
  description = "ECS service IAM role"
}

variable "ecs_container_name" {
  description = "ECS container task name"
}

variable "ecs_app_min_capacity" {
  description = "Minimum number of containers to run"
  default = 2
}

variable "ecs_app_max_capacity" {
  description = "Maximum number of containers to run"
  default = 6
}

variable "ecs_service_autoscale" {
  description = "The IAM role used to autoscale the number of containers based on CW metrics"
}

variable "nlb_subnets" {
  description = "Subnets list for the Network Load Balancer"
  type        = "list"
}

variable "nlb_vpc" {
  description = "VPC for the TargetGroup Load Balancer"
}
