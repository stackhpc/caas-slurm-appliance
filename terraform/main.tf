terraform {
  required_version = ">= 0.14"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

#####
##### Security groups for the cluster
#####

resource "openstack_networking_secgroup_v2" "secgroup_slurm_login" {
  name                 = "${var.cluster_name}-secgroup-slurm-login"
  description          = "Rules for the slurm login node"
  delete_default_rules = true   # Fully manage with terraform
}

resource "openstack_networking_secgroup_v2" "secgroup_slurm_compute" {
  name                 = "${var.cluster_name}-secgroup-slurm-compute"
  description          = "Rules for the slurm compute node"
  delete_default_rules = true   # Fully manage with terraform
}

## Allow all egress for login and compute nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_egress_v4" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_login.id
}
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_compute_rule_egress_v4" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_compute.id
}

## Allow all ingress between nodes in the cluster
# login -> login
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_ingress_login_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.secgroup_slurm_login.id
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_login.id
}
# compute -> login
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_ingress_compute_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.secgroup_slurm_compute.id
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_login.id
}
# login -> compute
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_compute_rule_ingress_login_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.secgroup_slurm_login.id
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_compute.id
}
# compute -> compute
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_compute_rule_ingress_compute_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.secgroup_slurm_compute.id
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_compute.id
}

## Allow ingress on port 22 (SSH) from anywhere for the login nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_ingress_ssh_v4" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_login.id
}


#####
##### Cluster nodes
#####

resource "openstack_compute_instance_v2" "login" {
  name      = "${var.cluster_name}-login-0"
  image_id  = var.login_image
  flavor_id = var.login_flavor
  key_pair  = var.key_pair
  network {
    name = var.cluster_network
  }
  security_groups = [openstack_networking_secgroup_v2.secgroup_slurm_login.name]
}

resource "openstack_compute_instance_v2" "compute" {
  count = var.compute_count

  name      = "${var.cluster_name}-compute-${count.index}"
  image_id  = var.compute_image
  flavor_id = var.compute_flavor
  key_pair  = var.key_pair
  network {
    name = var.cluster_network
  }
  security_groups = [openstack_networking_secgroup_v2.secgroup_slurm_compute.name]
}


#####
##### Floating IP association for login node
#####

resource "openstack_compute_floatingip_associate_v2" "login_floatingip_assoc" {
  floating_ip = var.cluster_floating_ip
  instance_id = openstack_compute_instance_v2.login.id
}
