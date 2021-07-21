variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
}

variable "cluster_network" {
  type        = string
  description = "The name of the network to connect cluster nodes to"
}

variable "cluster_floating_ip" {
  type        = string
  description = "The floating IP to associate with the login node"
}

variable "key_pair" {
  type        = string
  description = "The name of the OpenStack keypair to use"
}

variable "compute_count" {
  type        = number
  description = "The number of compute nodes in the cluster"
}

variable "login_image" {
  type = string
  description = "The ID of the CentOS 8 image to use for the login node"
}

variable "control_image" {
  type = string
  description = "The ID of the CentOS 8 image to use for the control node"
}

variable "compute_image" {
  type = string
  description = "The ID of the CentOS 8 image to use for the compute nodes"
}

variable "login_flavor" {
  type = string
  description = "The ID of the flavor to use for the login node"
}

variable "control_flavor" {
  type = string
  description = "The ID of the flavor to use for the control node"
}

variable "compute_flavor" {
  type = string
  description = "The ID of the flavor to use for the compute nodes"
}
