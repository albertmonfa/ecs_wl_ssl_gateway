resource "aws_ecs_task_definition" "app_ecs_td" {
  family = "${var.project_name}"
  container_definitions = "${file("ecs/app-task-definition.json")}"
}

resource "aws_ecs_service" "app_ecs_service" {
  name                = "${var.project_name}-${var.env}-service"
  cluster             = "${var.ecs_cluster_name}"
  task_definition     = "${aws_ecs_task_definition.app_ecs_td.arn}"
  iam_role            = "${var.ecs_service_role}"

  desired_count                       = "${var.ecs_app_min_capacity}"
  deployment_minimum_healthy_percent  = 33
  deployment_maximum_percent          = 200

  load_balancer {
    target_group_arn = "${aws_lb_target_group.app_nlb_tg.arn}"
    container_name = "${var.ecs_container_name}"
    container_port = 443
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_service_cpu_high" {
  alarm_name = "${var.project_name}-${var.env}-service-cpu-utilization-above-80"
  alarm_description = "This alarm monitors ${var.project_name}-${var.env}-service CPU utilization for scaling up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  period = "120"
  statistic = "Average"
  threshold = "80"
  alarm_actions = ["${aws_appautoscaling_policy.cpu_app_scale_up.arn}"]

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.project_name}-${var.env}-service"
  }
  depends_on = ["aws_appautoscaling_policy.cpu_app_scale_up"]
}

resource "aws_cloudwatch_metric_alarm" "app_service_cpu_low" {
  alarm_name = "${var.project_name}-${var.env}-service-cpu-utilization-below-5"
  alarm_description = "This alarm monitors ${var.project_name}-${var.env}-service CPU utilization for scaling down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  period = "120"
  statistic = "Average"
  threshold = "5"
  alarm_actions = ["${aws_appautoscaling_policy.cpu_app_scale_down.arn}"]

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.project_name}-${var.env}-service"
  }
  depends_on = ["aws_appautoscaling_policy.cpu_app_scale_down"]
}

resource "aws_cloudwatch_metric_alarm" "app_service_memory_high" {
  alarm_name = "${var.project_name}-${var.env}-service-memory-utilization-above-80"
  alarm_description = "This alarm monitors ${var.project_name}-${var.env}-service memory utilization for scaling up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "MemoryUtilization"
  namespace = "AWS/ECS"
  period = "120"
  statistic = "Average"
  threshold = "80"
  alarm_actions = ["${aws_appautoscaling_policy.mem_app_scale_up.arn}"]

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.project_name}-${var.env}-service"
  }
  depends_on = ["aws_appautoscaling_policy.mem_app_scale_up"]
}

resource "aws_cloudwatch_metric_alarm" "app_service_memory_low" {
  alarm_name = "${var.project_name}-${var.env}-service-memory-utilization-below-5"
  alarm_description = "This alarm monitors ${var.project_name}-${var.env}-service memory utilization for scaling down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "MemoryUtilization"
  namespace = "AWS/ECS"
  period = "120"
  statistic = "Average"
  threshold = "5"
  alarm_actions = ["${aws_appautoscaling_policy.mem_app_scale_down.arn}"]

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.project_name}-${var.env}-service"
  }
  depends_on = ["aws_appautoscaling_policy.mem_app_scale_down"]
}

resource "aws_appautoscaling_target" "app_target" {
  resource_id = "service/${var.ecs_cluster_name}/${var.project_name}-${var.env}-service"
  role_arn = "${var.ecs_service_autoscale}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity = "${var.ecs_app_min_capacity}"
  max_capacity = "${var.ecs_app_max_capacity}"
  service_namespace       = "ecs"
  depends_on = ["aws_ecs_service.app_ecs_service"]
}

resource "aws_appautoscaling_policy" "cpu_app_scale_up" {
  name = "${var.project_name}-${var.env}-service-cpu-scale-up"
  resource_id = "service/${var.ecs_cluster_name}/${var.project_name}-${var.env}-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 1
    }
  }
  depends_on = ["aws_appautoscaling_target.app_target"]
}

resource "aws_appautoscaling_policy" "cpu_app_scale_down" {
  name = "${var.project_name}-${var.env}-service-cpu-scale-down"
  resource_id = "service/${var.ecs_cluster_name}/${var.project_name}-${var.env}-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
depends_on = ["aws_appautoscaling_target.app_target"]
}

resource "aws_appautoscaling_policy" "mem_app_scale_up" {
  name = "${var.project_name}-${var.env}-service-mem-scale-up"
  resource_id = "service/${var.ecs_cluster_name}/${var.project_name}-${var.env}-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 1
    }
  }
  depends_on = ["aws_appautoscaling_target.app_target"]
}

resource "aws_appautoscaling_policy" "mem_app_scale_down" {
  name = "${var.project_name}-${var.env}-service-mem-scale-down"
  resource_id = "service/${var.ecs_cluster_name}/${var.project_name}-${var.env}-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
depends_on = ["aws_appautoscaling_target.app_target"]
}
