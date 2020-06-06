variable "env" {
  description = "Used to define environment type, also used in state prefix output"
  type        = string
  default     = "dev"
}

variable "credentials" {
  description = "JSON file path for Terraform Service Account"
  type        = string
}

variable "project" {
  description = "GCP project"
  type        = string
}

variable "region" {
  description = "Region for deployments"
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "Zone for deployments"
  type        = string
  default     = "c"
}

variable "state" {
  description = "GCS bucket to save tf state"
  type        = string
}

variable "cluster_name" {
  description = "GKE k8s cluster name"
  type        = string
  default     = "default-cluster"
}

variable "node_pool_name" {
  description = "GKE k8s node pool name"
  type = string
  default = "default-pool"
}


variable "initial_node_count" {
  description = "Initial node count for k8s cluster"
  default     = 1
}

variable "network" {
  description = "Networks the k8s cluster sits in"
  type        = string
  default     = "default"
}

variable "machine_type" {
  description = "Machine type for cluster nodes"
  type        = string
  default     = "n1-standard-1"
}

variable "preemptible" {
  description = "Defines whether node machines are preemptible or not"
  type = string
  default = true
}
