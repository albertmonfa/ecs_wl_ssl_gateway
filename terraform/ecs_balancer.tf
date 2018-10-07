resource "aws_lb" "app_nlb" {
  name                          = "${var.project_name}-nlb-${var.env}"
  subnets                       = "${var.nlb_subnets}"

  internal                      = false
  enable_deletion_protection    = false
  load_balancer_type            = "network"
  idle_timeout                  = 30

  tags {
    Name               = "${var.project_name}-nlb-${var.env}"
    COMMON_name             = "${var.project_name}-nlb-${var.env}"
    COMMON_environment      = "${var.env}"
    COMMON_itops_automation = "yes"
    COMMON_project          = "${var.project_name}"
    COMMON_type             = "NLB"
  }
}

resource "aws_lb_target_group" "app_nlb_tg" {
  name     = "${var.project_name}-tg-${var.env}"
  vpc_id   = "${var.nlb_vpc}"

  deregistration_delay      = 60
  port                      = 443
  protocol                  = "TCP"

  health_check {
    interval = 10
    protocol = "TCP"
    healthy_threshold = 3
    unhealthy_threshold = 3
  }

  tags {
    Name               = "${var.project_name}-tg-${var.env}"
    COMMON_name             = "${var.project_name}-tg-${var.env}"
    COMMON_environment      = "${var.env}"
    COMMON_itops_automation = "yes"
    COMMON_project          = "${var.project_name}"
    COMMON_type             = "TG"
  }

  depends_on = ["aws_lb.app_nlb"]
}

resource "aws_lb_listener" "app_nlb_listener_https" {
  load_balancer_arn = "${aws_lb.app_nlb.arn}"
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.app_nlb_tg.arn}"
    type             = "forward"
  }

  depends_on = ["aws_lb_target_group.app_nlb_tg"]
}

resource "aws_lb_listener" "app_nlb_listener_http" {
  load_balancer_arn = "${aws_lb.app_nlb.arn}"
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.app_nlb_tg.arn}"
    type             = "forward"
  }

  depends_on = ["aws_lb_target_group.app_nlb_tg"]
}
