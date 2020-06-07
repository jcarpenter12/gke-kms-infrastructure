provider "google" {

  credentials = file(var.credentials)

  project = var.project
  region  = var.region
  zone    = var.zone
}

// At this time this is required in order to use the kms encryption on the k8s cluster
provider "google-beta" {

  credentials = file(var.credentials)

  project = var.project
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {}
}
// Used to get the project number so the gke account used to set up the cluster
// can be assigned permissons for the application layer encryption
data "google_project" "project" {
}

// Create a kms key use to encrypt K8s secrets
resource "google_kms_key_ring" "key_ring" {
  project  = var.project
  name     = "${var.env}-gke-key-ring"
  location = var.region
}

resource "google_kms_crypto_key" "kube_secrets_key" {
  name     = "${var.env}_kube_secrets_key"
  key_ring = google_kms_key_ring.key_ring.self_link
}

resource "google_project_iam_binding" "gke-sa-role-kms" {
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
   "serviceAccount:service-${data.google_project.project.number}@container-engine-robot.iam.gserviceaccount.com"
  ]
}

// Create k8s cluster
resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region
  initial_node_count = var.initial_node_count

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

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  depends_on = [google_kms_crypto_key.kube_secrets_key,google_project_iam_binding.gke-sa-role-kms]
}
