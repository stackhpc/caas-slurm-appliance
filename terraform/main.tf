terraform {
  required_version = ">= 0.14"

  # We need the OpenStack provider
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }

  # The Terraform state lives in Consul
  backend "consul" { gzip = true }
}

#####
##### Security groups for the cluster
#####

# Security group to hold common rules for the cluster
resource "openstack_networking_secgroup_v2" "secgroup_slurm_cluster" {
  name                 = "${var.cluster_name}-secgroup-slurm-cluster"
  description          = "Rules for the slurm cluster nodes"
  delete_default_rules = true   # Fully manage with terraform
}

# Security group to hold specific rules for the login node
resource "openstack_networking_secgroup_v2" "secgroup_slurm_login" {
  name                 = "${var.cluster_name}-secgroup-slurm-login"
  description          = "Specific rules for the slurm login node"
  delete_default_rules = true   # Fully manage with terraform
}

## Allow all egress for all cluster nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_cluster_rule_egress_v4" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_cluster.id
}

## Allow all ingress between nodes in the cluster
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_cluster_rule_ingress_internal_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.secgroup_slurm_cluster.id
  security_group_id = openstack_networking_secgroup_v2.secgroup_slurm_cluster.id
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
  network {
    name = var.cluster_network
  }
  security_groups = [
    openstack_networking_secgroup_v2.secgroup_slurm_cluster.name,
    openstack_networking_secgroup_v2.secgroup_slurm_login.name
  ]
  # Use cloud-init to inject the SSH keys
  user_data = <<-EOF
    #cloud-config

    ssh_authorized_keys:
      %{ for key in var.cluster_ssh_public_keys }
      - ${key}
      %{ endfor }
  EOF
}

resource "openstack_compute_instance_v2" "control" {
  name      = "${var.cluster_name}-control-0"
  image_id  = var.control_image
  flavor_id = var.control_flavor
  network {
    name = var.cluster_network
  }
  security_groups = [openstack_networking_secgroup_v2.secgroup_slurm_cluster.name]
  # Use cloud-init to inject the SSH keys
  user_data = <<-EOF
    #cloud-config

    ssh_authorized_keys:
      %{ for key in var.cluster_ssh_public_keys }
      - ${key}
      %{ endfor }
  EOF
}

resource "openstack_compute_instance_v2" "compute" {
  count = var.compute_count

  name      = "${var.cluster_name}-compute-${count.index}"
  image_id  = var.compute_image
  flavor_id = var.compute_flavor
  network {
    name = var.cluster_network
  }
  security_groups = [openstack_networking_secgroup_v2.secgroup_slurm_cluster.name]
  # Use cloud-init to inject the SSH keys
  user_data = <<-EOF
    #cloud-config

    ssh_authorized_keys:
      %{ for key in var.cluster_ssh_public_keys }
      - ${key}
      %{ endfor }
  EOF
}

#####
##### Floating IP association for login node
#####

resource "openstack_compute_floatingip_associate_v2" "login_floatingip_assoc" {
  floating_ip = var.cluster_floating_ip
  instance_id = openstack_compute_instance_v2.login.id
}
