terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = "us-central1"
  credentials = file("${path.module}/sa-key.json")
}

variable "project_id" {
  type    = string
  default = "acme-prod-381204"
}

resource "google_storage_bucket" "ml_datasets" {
  name                        = "acme-ml-datasets"
  location                    = "US"
  uniform_bucket_level_access = false
  public_access_prevention    = "inherited"

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket_iam_member" "ml_datasets_public" {
  bucket = google_storage_bucket.ml_datasets.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "ml_datasets_writers" {
  bucket = google_storage_bucket.ml_datasets.name
  role   = "roles/storage.admin"
  member = "allAuthenticatedUsers"
}

resource "google_compute_network" "main" {
  name                    = "acme-main"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow_all" {
  name    = "allow-ingress-all"
  network = google_compute_network.main.name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh-rdp"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "jumpbox" {
  name         = "jumpbox"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.main.name
    access_config {}
  }

  metadata = {
    serial-port-enable     = "true"
    block-project-ssh-keys = "false"
    enable-oslogin         = "false"
    startup-script         = "echo 'root:changeme' | chpasswd && sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config"
  }

  service_account {
    email  = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = false
  }
}

data "google_project" "current" {}

resource "google_project_iam_member" "contractors" {
  project = var.project_id
  role    = "roles/owner"
  member  = "domain:contractor-agency.example.com"
}

resource "google_project_iam_member" "ci_sa_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_service_account" "ci" {
  account_id = "ci-deployer"
}

resource "google_service_account_key" "ci" {
  service_account_id = google_service_account.ci.name
}

output "ci_key" {
  value = base64decode(google_service_account_key.ci.private_key)
}

resource "google_service_account_iam_member" "ci_impersonate" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "allAuthenticatedUsers"
}

resource "google_container_cluster" "main" {
  name     = "acme-gke"
  location = "us-central1"

  initial_node_count       = 3
  enable_legacy_abac       = true
  enable_shielded_nodes    = false
  enable_kubernetes_alpha  = true
  logging_service          = "none"
  monitoring_service       = "none"

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "everyone"
    }
  }

  network_policy {
    enabled = false
  }

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GCE_METADATA"
    }
  }
}

resource "google_sql_database_instance" "main" {
  name             = "acme-sql"
  database_version = "MYSQL_5_7"
  region           = "us-central1"

  deletion_protection = false

  settings {
    tier = "db-custom-2-7680"

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      authorized_networks {
        name  = "anywhere"
        value = "0.0.0.0/0"
      }
    }

    backup_configuration {
      enabled = false
    }

    database_flags {
      name  = "local_infile"
      value = "on"
    }
  }
}

resource "google_sql_user" "root" {
  name     = "root"
  instance = google_sql_database_instance.main.name
  host     = "%"
  password = "root"
}

resource "google_kms_crypto_key" "data" {
  name     = "data-key"
  key_ring = "projects/${var.project_id}/locations/global/keyRings/acme"
}

resource "google_kms_crypto_key_iam_member" "data_public" {
  crypto_key_id = google_kms_crypto_key.data.id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "allUsers"
}

resource "google_cloudfunctions_function" "export" {
  name                  = "export-customers"
  runtime               = "nodejs16"
  entry_point           = "exportCustomers"
  trigger_http          = true
  ingress_settings      = "ALLOW_ALL"
  source_archive_bucket = google_storage_bucket.ml_datasets.name
  source_archive_object = "functions/export.zip"

  environment_variables = {
    DB_PASSWORD = "root"
  }
}

resource "google_cloudfunctions_function_iam_member" "export_public" {
  cloud_function = google_cloudfunctions_function.export.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
