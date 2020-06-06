provider "google" {

  credentials = file(var.credentials)

  project = var.project
  region  = var.region
  zone    = var.zone
}

// At this is required in order to use the kms encryption on the k8s cluster
provider "google-beta" {

  credentials = file(var.credentials)

  project = var.project
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {}
}

// Create a kms key use to encrypt K8s secrets
resource "google_kms_key_ring" "key_ring" {
  project  = var.project
  name     = "${var.env}-key-ring"
  location = var.region
}

resource "google_kms_crypto_key" "kube_secrets_key" {
  name     = "${var.env}_kube_secrets_key"
  key_ring = google_kms_key_ring.key_ring.self_link
}

resource "google_service_account" "gke-sa" {
    account_id   = "${var.env}-gke-sa"
    display_name = "${var.env} GKE Service Account"
}

/* resource "google_project_iam_binding" "gke-sa-role-container" { */
/*   role    = "roles/container.admin" */
/*   members = [ */
/*    "serviceAccount:${google_service_account.gke-sa.email}" */
/*   ] */
/* } */

/* resource "google_project_iam_binding" "gke-sa-role-kms" { */
/*   role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter" */
/*   members = [ */
/*    "serviceAccount:${google_service_account.gke-sa.email}" */
/*   ] */
/* } */

// Create k8s cluster
resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  database_encryption {
    state = "ENCRYPTED"
    key_name = google_kms_crypto_key.kube_secrets_key.self_link
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  /* auto_provisioning_defaults { */
  /*   service_account = google_service_account.gke-sa */
  /* } */

  depends_on = [google_kms_crypto_key.kube_secrets_key]
}


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = var.node_pool_name
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.initial_node_count

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

}
