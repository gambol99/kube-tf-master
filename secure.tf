#
## Kuberneres Secure Layer Resources
#

##  Role Policy Template
data "template_file" "secure" {
  template = "${file("${path.module}/assets/iam/secure-role.json")}"

  vars = {
    aws_region          = "${var.aws_region}"
    environment         = "${var.environment}"
    kms_master_id       = "${var.kms_master_id}"
    secrets_bucket_name = "${var.secrets_bucket_name}"
  }
}

## Instance profile
resource "aws_iam_instance_profile" "secure" {
  name  = "${var.environment}-secure"
  roles = [ "${aws_iam_role.secure.name}" ]
}

## UserData template
data "gotemplate_file" "secure_user_data" {
  template = "${file("${path.module}/assets/cloudinit/secure.yml")}"

  vars = {
    aws_region             = "${var.aws_region}"
    enable_calico          = "${var.enable_calico}"
    environment            = "${var.environment}"
    etcd_memberlist        = "${join(",", formatlist("%s=https://%s:2380", keys(var.secure_nodes), values(var.secure_nodes)))}"
    flannel_cidr           = "${var.flannel_cidr}"
    kmsctl_image           = "${var.kmsctl_image}"
    kmsctl_release_md5     = "${var.kmsctl_release_md5}"
    kmsctl_release_url     = "${var.kmsctl_release_url}"
    kubernetes_image       = "${element(split(":", var.kubernetes_image), 0)}"
    kubernetes_version     = "${element(split(":", var.kubernetes_image), 1)}"
    private_zone_name      = "${var.private_zone_name}"
    public_zone_name       = "${var.public_zone_name}"
    secrets_bucket_name    = "${var.secrets_bucket_name}"
    smilodon_release_md5   = "${var.smilodon_release_md5}"
    smilodon_release_url   = "${var.smilodon_release_url}"
  }
}

## Secure Launch Configuration
resource "aws_launch_configuration" "secure" {
  associate_public_ip_address = false
  enable_monitoring           = false
  iam_instance_profile        = "${aws_iam_instance_profile.secure.name}"
  image_id                    = "${data.aws_ami.coreos.id}"
  instance_type               = "${var.secure_flavor}"
  key_name                    = "${var.key_name}"
  name_prefix                 = "${var.environment}-secure-asg${count.index}"
  security_groups             = [ "${var.secure_sg}" ]
  user_data                   = "${data.gotemplate_file.secure_user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = "${var.secure_root_volume}"
    volume_type           = "gp2"
  }

  ebs_block_device {
    delete_on_termination = true
    device_name           = "/dev/xvdd"
    volume_size           = "${var.secure_docker_volume}"
    volume_type           = "gp2"
  }
}

## Secure AutoScaling Group
resource "aws_autoscaling_group" "secure" {
  count                     = "${length(var.secure_nodes_asg)/2}"

  default_cooldown          = "${var.secure_asg_grace_period}"
  desired_capacity          = "${lookup(var.secure_nodes_asg, "zone${count.index}_size")}"
  force_delete              = true
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.secure.name}"
  max_size                  = "${lookup(var.secure_nodes_asg, "zone${count.index}_size")+1}"
  min_size                  = "${lookup(var.secure_nodes_asg, "zone${count.index}_size")}"
  name                      = "${var.environment}-secure-asg${count.index}"
  termination_policies      = [ "OldestInstance", "Default" ]
  vpc_zone_identifier       = [ "${lookup(var.secure_subnets, lookup(var.secure_nodes_asg, "zone${count.index}_zone"))}" ]

  tag {
    key                 = "Name"
    value               = "${var.environment}-secure"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "secure"
    propagate_at_launch = true
  }

  tag {
    key                 = "KubernetesCluster"
    value               = "${var.environment}"
    propagate_at_launch = true
  }
}
