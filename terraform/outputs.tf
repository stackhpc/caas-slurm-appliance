output "cluster_gateway_ip" {
  description = "The IP address of the gateway used to contact the cluster nodes"
  value       = var.cluster_floating_ip
}

#####
## WARNING
##
## The groups specified here should replicate the groups in the StackHPC Slurm appliance environments
##
## https://github.com/stackhpc/ansible-slurm-appliance/blob/main/environments/common/inventory/groups
## https://github.com/stackhpc/ansible-slurm-appliance/blob/main/environments/common/layouts/everything
#####
output "cluster_nodes" {
  description = "A list of the nodes in the cluster from which an Ansible inventory will be populated"
  value       = concat(
    [
      {
        name   = openstack_compute_instance_v2.login.name
        ip     = openstack_compute_instance_v2.login.network[0].fixed_ip_v4
        groups = [
          "cluster",
          "openhpc",
          "login",
          "selinux",
          "nfs",
          "node_exporter",
          "update",
        ]
      },
      {
        name   = openstack_compute_instance_v2.control.name
        ip     = openstack_compute_instance_v2.control.network[0].fixed_ip_v4
        groups = [
          "cluster",
          "openhpc",
          "control",
          "selinux",
          "nfs",
          "mysql",
          "prometheus",
          "grafana",
          "alertmanager",
          "node_exporter",
          "podman",
          "opendistro",
          "kibana",
          "slurm_stats",
          "filebeat",
          "update",
        ]
      }
    ],
    [
      for compute in openstack_compute_instance_v2.compute: {
        name   = compute.name
        ip     = compute.network[0].fixed_ip_v4
        groups = [
          "cluster",
          "openhpc",
          "compute",
          "selinux",
          "nfs",
          "node_exporter",
          "update",
        ]
      }
    ]
  )
}
