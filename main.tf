locals {
  env_FQDN = "${var.env_name}.${var.route53_hosted_zone_name}"
  common_tags = {
    Environment = "dev"
    Owner       = var.owner_team
  }
}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Venafi cert
# -----------------------------------------------------------------------------
resource "venafi_certificate" "domo" {
  common_name = local.env_FQDN
}

# -----------------------------------------------------------------------------
# ACM
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "domo_cert" {
  private_key       = venafi_certificate.domo.private_key_pem
  certificate_body  = venafi_certificate.domo.certificate
  certificate_chain = venafi_certificate.domo.chain
}

# resource "aws_acm_certificate_validation" "domo_cert_validation" {
#   certificate_arn         = aws_acm_certificate.domo_cert.arn
#   validation_record_fqdns = [aws_route53_record.domo_cert_validation_record.fqdn]
# }

# -----------------------------------------------------------------------------
# AMIs
# -----------------------------------------------------------------------------
data "aws_ami" "domo_ami" {
  most_recent = true
  # owners      = ["099720109477"]  # Official Canonical https://help.ubuntu.com/community/EC2StartersGuide
  owners      = ["430256340876"]

  filter {
    name   = "name"
    # values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    values = ["nginx-ubuntu*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------------------------------------------------------------
# Cloud Init
# -----------------------------------------------------------------------------
data "template_file" "user_data_script" {
  template = file("${path.module}/templates/ec2_user_data.sh.tpl")
  vars     = {
    motd = <<-EOF
  Domo machine
EOF
  }
}

data "template_cloudinit_config" "domo_cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.user_data_script.rendered
  }
}

################################################
# IAM
################################################
resource "aws_iam_role" "domo_instance_role" {
  name               = "${var.env_name}-domo-instance-role-${data.aws_region.current.name}"
  path               = "/"
  assume_role_policy = file("${path.module}/templates/domo-instance-role.json")

  tags = merge({ Name = "${var.env_name}-domo-instance-role" }, local.common_tags)
}

resource "aws_iam_role_policy" "domo_instance_role_policy" {
  name   = "${var.env_name}-domo-instance-role-policy-${data.aws_region.current.name}"
  policy = file("${path.module}/templates/domo-instance-role-policy.json")
  role   = aws_iam_role.domo_instance_role.id
}

resource "aws_iam_instance_profile" "domo_instance_profile" {
  name = "${var.env_name}-domo-instance-profile-${data.aws_region.current.name}"
  path = "/"
  role = aws_iam_role.domo_instance_role.name
}

################################################
# Security Groups
################################################
resource "aws_security_group" "domo_alb_allow" {
  name   = "${var.env_name}-domo-alb-allow"
  vpc_id = var.aws_vpc_id
  tags   = merge({ Name = "${var.env_name}-domo-alb-allow" }, local.common_tags)
}

resource "aws_security_group_rule" "domo_alb_allow_inbound_https" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.ingress_cidr_alb_allow
  description = "Allow HTTPS (port 443) traffic inbound to domo ALB"

  security_group_id = aws_security_group.domo_alb_allow.id
}

resource "aws_security_group_rule" "domo_alb_allow_inbound_http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.ingress_cidr_alb_allow
  description = "Allow HTTP (port 80) traffic inbound to domo ALB"

  security_group_id = aws_security_group.domo_alb_allow.id
}

resource "aws_security_group" "domo_ec2_allow" {
  name   = "${var.env_name}-domo-ec2-allow"
  vpc_id = var.aws_vpc_id
  tags   = merge({ Name = "${var.env_name}-domo-ec2-allow" }, local.common_tags)
}

resource "aws_security_group_rule" "domo_ec2_allow_https_inbound_from_alb" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.domo_alb_allow.id
  description              = "Allow HTTPS (port 443) traffic inbound to domo EC2 instance from domo Appication Load Balancer"

  security_group_id = aws_security_group.domo_ec2_allow.id
}

resource "aws_security_group_rule" "domo_ec2_allow_http_inbound_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.domo_alb_allow.id
  description              = "Allow HTTP (port 80) traffic inbound to domo EC2 instance from domo Appication Load Balancer"

  security_group_id = aws_security_group.domo_ec2_allow.id
}

resource "aws_security_group_rule" "domo_ec2_allow_inbound_ssh" {
  count       = length(var.domo_ingress_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.domo_ingress_cidr_blocks
  description = "Allow SSH inbound to domo EC2 instance CIDR ranges listed"

  security_group_id = aws_security_group.domo_ec2_allow.id
}

resource "aws_security_group" "domo_outbound_allow" {
  name   = "${var.env_name}-domo-outbound-allow"
  vpc_id = var.aws_vpc_id
  tags   = merge({ Name = "${var.env_name}-domo-outbound-allow" }, local.common_tags)
}

resource "aws_security_group_rule" "domo_outbound_allow_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all traffic outbound from domo"

  security_group_id = aws_security_group.domo_outbound_allow.id
}

################################################
# Auto Scaling
################################################
resource "aws_launch_template" "domo_lt" {
  name          = "${var.env_name}-domo-ec2-asg-lt"
  image_id      = data.aws_ami.domo_ami.id
  instance_type = "t2.micro"
  key_name      = var.key_pair_name != "" ? var.key_pair_name : ""
  user_data     = data.template_cloudinit_config.domo_cloudinit.rendered

  iam_instance_profile {
    name = aws_iam_instance_profile.domo_instance_profile.name
  }

  vpc_security_group_ids = [
    aws_security_group.domo_ec2_allow.id,
    aws_security_group.domo_outbound_allow.id
  ]

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      { Name = "${var.env_name}-domo-ec2" },
      { Type = "autoscaling-group" },
      local.common_tags
    )
  }

  tags = merge({ Name = "${var.env_name}-domo-ec2-launch-template" }, local.common_tags)
}

resource "aws_autoscaling_group" "domo_asg" {
  name                      = "${var.env_name}-domo-asg"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.ec2_subnet_ids
  health_check_grace_period = 600
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.domo_lt.id
    version = "$Latest"
  }
  target_group_arns = [
    aws_lb_target_group.domo_tg_443.arn
  ]
}

################################################
# Load Balancing
################################################
resource "aws_lb" "domo_alb" {
  name               = "${var.env_name}-domo-web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.domo_alb_allow.id,
    aws_security_group.domo_outbound_allow.id
  ]

  subnets = var.alb_subnet_ids

  tags = merge({ Name = "${var.env_name}-domo-alb" }, local.common_tags)
}

resource "aws_lb_listener" "domo_listener_443" {
  load_balancer_arn = aws_lb.domo_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.domo_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.domo_tg_443.arn
  }

  depends_on = [aws_acm_certificate.domo_cert]
}

resource "aws_lb_target_group" "domo_tg_443" {
  name     = "${var.env_name}-domo-alb-tg-443"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.aws_vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
  }

  tags = merge(
    { Name = "${var.env_name}-domo-alb-tg-443" },
    { Description = "ALB Target Group for domo web application HTTP traffic" },
    local.common_tags
  )
}

################################################
# Route53
################################################
data "aws_route53_zone" "selected" {
  name         = var.route53_hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "domo_alb_alias_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.env_FQDN
  type    = "A"

  alias {
    name                   = aws_lb.domo_alb.dns_name
    zone_id                = aws_lb.domo_alb.zone_id
    evaluate_target_health = false
  }
}

# resource "aws_route53_record" "domo_cert_validation_record" {
#   name    = aws_acm_certificate.domo_cert.domain_validation_options[0].resource_record_name
#   type    = aws_acm_certificate.domo_cert.domain_validation_options[0].resource_record_type
#   zone_id = data.aws_route53_zone.selected.zone_id
#   records = [aws_acm_certificate.domo_cert.domain_validation_options[0].resource_record_value]
#   ttl     = 60
# }
