
## ETCD ELB Security Group
resource "aws_security_group" "etcd_elb" {
  name        = "${var.environment}-etcd-elb"
  description = "Etcd ELB Security Group for ${var.environment} environment"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "${var.environment}-etcd-elb"
    Env  = "${var.environment}"
    Role = "etcd-elb"
  }
}

#
## Ingress Secure
#

## Permit Etcd client from compute boxes
resource "aws_security_group_rule" "secure_permit_etcd_client" {
  type                     = "ingress"
  security_group_id        = "${var.secure_sg}"
  protocol                 = "tcp"
  from_port                = "2379"
  to_port                  = "2379"
  source_security_group_id = "${var.compute_sg}"
}

## Permit flannel vxlan udp from compute
resource "aws_security_group_rule" "secure_permit_vxlan" {
  type                     = "ingress"
  security_group_id        = "${var.secure_sg}"
  protocol                 = "udp"
  from_port                = "8472"
  to_port                  = "8472"
  source_security_group_id = "${var.compute_sg}"
}

## Permit kube api from compute
resource "aws_security_group_rule" "secure_permit_6443" {
  type                     = "ingress"
  security_group_id        = "${var.secure_sg}"
  protocol                 = "tcp"
  from_port                = "6443"
  to_port                  = "6443"
  source_security_group_id = "${var.compute_sg}"
}

## Permit Kubernetes Exec client from secure api
resource "aws_security_group_rule" "compute_permit_10250" {
  type                     = "ingress"
  security_group_id        = "${var.compute_sg}"
  protocol                 = "tcp"
  from_port                = "10250"
  to_port                  = "10250"
  source_security_group_id = "${var.secure_sg}"
}

## Permit all inbound connections from the ELB layer to service ports
resource "aws_security_group_rule" "compute_node_ports_32000" {
  type                     = "ingress"
  security_group_id        = "${var.compute_sg}"
  protocol                 = "tcp"
  from_port                = "30000"
  to_port                  = "32767"
  cidr_blocks              = [ "${values(var.elb_cidr)}" ]
}

#
## Ingress Etcd ELB
#

## Ingress: Rule permits compute subnets access to Kubernetes API
resource "aws_security_group_rule" "etcd_elb_permit_2379_compute" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.etcd_elb.id}"
  from_port                = 2379
  to_port                  = 2379
  protocol                 = "tcp"
  source_security_group_id = "${var.compute_sg}"
}

## Ingress: Rule permits traffic from etcd -> elb
resource "aws_security_group_rule" "etcd_elb_permit_2379_secure" {
  type                     = "ingress"
  security_group_id        = "${var.secure_sg}"
  protocol                 = "tcp"
  from_port                = 2379
  to_port                  = 2379
  source_security_group_id = "${aws_security_group.etcd_elb.id}"
}

## Egress: Rule permits traffic from etcd -> elb
resource "aws_security_group_rule" "etcd_elb_outbound_2379" {
  type                     = "egress"
  security_group_id        = "${aws_security_group.etcd_elb.id}"
  protocol                 = "tcp"
  from_port                = 2379
  to_port                  = 2379
  source_security_group_id = "${var.secure_sg}"
}
