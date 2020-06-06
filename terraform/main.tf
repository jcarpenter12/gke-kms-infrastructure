// Setup provider
provider "google" {

  credentials = file(var.credentials)

  project = var.project
  region  = var.region
  zone    = var.zone
}

// At this time the beta is required in order to use the kms service with terraform
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

// Create a kms key ring to store the key
resource "google_kms_key_ring" "key_ring" {
  project  = var.project
  name     = "${var.env}-gke-key-ring"
  location = var.region
}

// Create the crypto key within the newly generated key ring
resource "google_kms_crypto_key" "kube_secrets_key" {
  name     = "${var.env}_gke_secrets_key"
  key_ring = google_kms_key_ring.key_ring.self_link
}

// The service account used to spin up the cluster requires access to the
// crypto key above in order to apply it to the gke cluster
resource "google_project_iam_binding" "gke-sa-role-kms" {
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
   "serviceAccount:service-${data.google_project.project.number}@container-engine-robot.iam.gserviceaccount.com"
  ]
}

//Enable Cloud Build to Access the Secret Manager for deploying secrets
resource "google_project_iam_binding" "cb-sa-role-sm" {
  role    = "roles/secretmanager.secretAccessor"
  members = [
   "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  ]
}

//Enable Cloud Build to Access the GKE Cluster to Deploy Apps
resource "google_project_iam_binding" "cb-sa-role-gke" {
  role    = "roles/container.developer"
  members = [
   "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  ]
}

// Create k8s cluster
resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region
  initial_node_count = var.initial_node_count

  // this enables application layer encryption on the gke cluster and points to
  // the key used to encrypt secrets
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

     oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    preemptible  = var.preemptible
    machine_type = var.machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  depends_on = [google_kms_crypto_key.kube_secrets_key,google_project_iam_binding.gke-sa-role-kms]
}
