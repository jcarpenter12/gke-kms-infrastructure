terraform import google_kms_key_ring.key_ring projects/jc-gke-project/locations/europe-west2/keyRings/dev-gke-key-ring
terraform import google_kms_crypto_key.kube_secrets_key projects/jc-gke-project/locations/europe-west2/keyRings/dev-gke-key-ring/cryptoKeys/dev_kube_secrets_key
