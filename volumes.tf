
## Etcd EBS volumes
resource "aws_ebs_volume" "etcd_volumes" {
  count             = "${length(var.secure_nodes)}"

  availability_zone = "${lookup(var.secure_nodes_zones, "node${count.index}_zone")}"
  encrypted         = "${var.secure_data_encrypted}"
  size              = "${var.secure_data_volume}"
  type              = "${var.secure_data_volume_type}"

  tags {
  	Role               = "etcd-data"
    Env                = "${var.environment}"
    KubernetesCluster  = "${var.environment}"
    Name               = "${var.environment}-etcd-node${count.index}"
    NodeID             = "${count.index}"
  }
}

## Etcd ENI Interfaces
resource "aws_network_interface" "etcd_eni" {
  count             = "${length(var.secure_nodes)}"

  private_ips       = [ "${lookup(var.secure_nodes, "node${count.index}")}" ]
  security_groups   = [ "${var.secure_sg}" ]
  source_dest_check = false
  subnet_id         = "${lookup(var.secure_subnets, lookup(var.secure_nodes_zones, "node${count.index}_zone"))}"

  tags {
    Env     = "${var.environment}"
    Name    = "${var.environment}-etcd-data"
    NodeID  = "${count.index}"
    Role    = "etcd-eni"
    Service = "etcd"
  }
}
