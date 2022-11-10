#####
##### The identity scope we are operating in
##### Used to output the OpenStack project ID as a fact for provisioned hosts
#####
data "openstack_identity_auth_scope_v3" "scope" {
  name = "{{ cluster_name }}"
}

#####
##### Security groups for the cluster
#####

# Security group to hold common rules for the cluster
resource "openstack_networking_secgroup_v2" "secgroup_slurm_cluster" {
  name                 = "{{ cluster_name }}-secgroup-slurm-cluster"
  description          = "Rules for the slurm cluster nodes"
  delete_default_rules = true   # Fully manage with terraform
}

# Security group to hold specific rules for the login node
resource "openstack_networking_secgroup_v2" "secgroup_slurm_login" {
  name                 = "{{ cluster_name }}-secgroup-slurm-login"
  description          = "Specific rules for the slurm login node"
  delete_default_rules = true   # Fully manage with terraform
}

## Allow all egress for all cluster nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_cluster_rule_egress_v4" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup_slurm_cluster.id}"
}

## Allow all ingress between nodes in the cluster
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_cluster_rule_ingress_internal_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = "${openstack_networking_secgroup_v2.secgroup_slurm_cluster.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup_slurm_cluster.id}"
}

## Allow ingress on port 22 (SSH) from anywhere for the login nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_ingress_ssh_v4" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${openstack_networking_secgroup_v2.secgroup_slurm_login.id}"
}

## Allow ingress on port 443 (HTTPS) from anywhere for the login nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_ingress_https_v4" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  security_group_id = "${openstack_networking_secgroup_v2.secgroup_slurm_login.id}"
}

## Allow ingress on port 80 (HTTP) from anywhere for the login nodes
resource "openstack_networking_secgroup_rule_v2" "secgroup_slurm_login_rule_ingress_http_v4" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  security_group_id = "${openstack_networking_secgroup_v2.secgroup_slurm_login.id}"
}

#####
##### Volumes
#####
resource "openstack_blockstorage_volume_v3" "state" {
    name = "{{ cluster_name }}-state"
    description = "State for control node"
    size = "{{ state_volume_size }}"
}

resource "openstack_blockstorage_volume_v3" "home" {
    name = "{{ cluster_name }}-home"
    description = "Home for control node"
    size = "{{ home_volume_size }}"
}


#####
##### Cluster nodes
#####

resource "openstack_compute_instance_v2" "login" {
  name      = "{{ cluster_name }}-login-0"
  image_id  = "{{ cluster_image }}"
  {% if login_flavor_name is defined %}
  flavor_name = "{{ login_flavor_name }}"
  {% else %}
  flavor_id = "{{ login_flavor }}"
  {% endif %}

  network {
    name = "{{ cluster_network }}"
  }
  security_groups = [
    "${openstack_networking_secgroup_v2.secgroup_slurm_cluster.name}",
    "${openstack_networking_secgroup_v2.secgroup_slurm_login.name}"
  ]

  depends_on = [
    openstack_compute_instance_v2.control
  ]

  # Use cloud-init to inject the SSH keys
  user_data = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - {{ cluster_deploy_ssh_public_key }}
      - {{ cluster_user_ssh_public_key }}
    {% if cluster_freeipa is defined and cluster_freeipa %}
    manage_resolv_conf: true
    nameservers:
      - "${openstack_compute_instance_v2.control.network[0].fixed_ip_v4}"
    {% endif %}
  EOF
}

resource "openstack_compute_instance_v2" "control" {
  name      = "{{ cluster_name }}-control-0"
  image_id  = "{{ cluster_image }}"
  {% if control_flavor_name is defined %}
  flavor_name = "{{ control_flavor_name }}"
  {% else %}
  flavor_id = "{{ control_flavor }}"
  {% endif %}
  
  network {
    name = "{{ cluster_network }}"
  }
  security_groups = ["${openstack_networking_secgroup_v2.secgroup_slurm_cluster.name}"]

  # root device:
  block_device {
      uuid = "{{ cluster_image }}"
      source_type  = "image"
      destination_type = "local"
      boot_index = 0
      delete_on_termination = true
  }

  # state volume:
  block_device {
      destination_type = "volume"
      source_type  = "volume"
      boot_index = -1
      uuid = openstack_blockstorage_volume_v3.state.id
  }

  # home volume:
  block_device {
      destination_type = "volume"
      source_type  = "volume"
      boot_index = -1
      uuid = openstack_blockstorage_volume_v3.home.id
  }

  # Use cloud-init to a) inject SSH keys b) configure volumes
  user_data = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - {{ cluster_deploy_ssh_public_key }}
      - {{ cluster_user_ssh_public_key }}
    fs_setup:
      - label: state
        filesystem: ext4
        device: {{ state_volume_device_path }}
        partition: auto
      - label: home
        filesystem: ext4
        device: {{ home_volume_device_path }}
        partition: auto
    mounts:
        - [LABEL=state, /var/lib/state]
        - [LABEL=home, /exports/home, auto, "x-systemd.required-by=nfs-server.service,x-systemd.before=nfs-server.service"]
  EOF
}

resource "openstack_compute_instance_v2" "compute" {
  count = {{ compute_count }}

  name      = "{{ cluster_name }}-compute-${count.index}"
  image_id  = "{{ cluster_image }}"
  flavor_id = "{{ compute_flavor }}"

  network {
    name = "{{ cluster_network }}"
  }

  depends_on = [
    openstack_compute_instance_v2.control
  ]

  security_groups = ["${openstack_networking_secgroup_v2.secgroup_slurm_cluster.name}"]
  # Use cloud-init to inject the SSH keys
  user_data = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - {{ cluster_deploy_ssh_public_key }}
      - {{ cluster_user_ssh_public_key }}
    {% if cluster_freeipa is defined and cluster_freeipa %}
    manage_resolv_conf: true
    nameservers:
      - "${openstack_compute_instance_v2.control.network[0].fixed_ip_v4}"
    {% endif %}
  EOF
}

#####
##### Floating IP association for login node
#####

resource "openstack_compute_floatingip_associate_v2" "login_floatingip_assoc" {
  floating_ip = "{{ cluster_floating_ip_address }}"
  instance_id = "${openstack_compute_instance_v2.login.id}"
}

