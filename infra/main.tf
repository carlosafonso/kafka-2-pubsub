terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.27.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.27.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "sourcerepo" {
  service            = "sourcerepo.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "clouddeploy" {
  service            = "clouddeploy.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "kafka-2-pubsub"
  auto_create_subnetworks = "false"
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "subnetwork" {
  name = "kafka-2-pubsub"
  ip_cidr_range = "10.0.0.0/24"
  region = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router" "router" {
  name = "kafka-2-pubsub"
  region = google_compute_subnetwork.subnetwork.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name = "kafka-2-pubsub"
  router = google_compute_router.router.name
  region = google_compute_router.router.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "rules" {
  name = "kafka-2-pubsub-allow-ssh"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_pubsub_topic" "topic" {
  name       = "kafka-2-pubsub"
  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_subscription" "subscription_a" {
  name = "kafka-2-pubsub-subscription-a"
  topic = google_pubsub_topic.topic.name
}

resource "google_pubsub_subscription" "subscription_b" {
  name = "kafka-2-pubsub-subscription-b"
  topic = google_pubsub_topic.topic.name
}

resource "google_artifact_registry_repository" "my-repo" {
  provider      = google-beta
  location      = var.region
  repository_id = "kafka-2-pubsub"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifactregistry]
}

resource "google_service_account" "gke" {
  account_id   = "kafka-2-pubsub-gke"
  display_name = "kafka2pubsub - Service account for the GKE cluster that allows it to interact with Pub/Sub"
  depends_on   = [google_project_service.iam]
}

resource "google_project_iam_member" "gke_pubsub_publisher" {
  project = var.project
  role = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_pubsub_subscriber" {
  project = var.project
  role = "roles/pubsub.subscriber"
  member = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_artifact_registry_viewer" {
  project = var.project
  role = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_container_cluster" "cluster" {
  name     = "kafka-2-pubsub"
  location = var.region
  network  = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnetwork.self_link

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "nodepool" {
  name = "kafka-2-pubsub"
  cluster = google_container_cluster.cluster.id
  node_count = 1

  node_config {
    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_service_account" "cloudbuild" {
  account_id   = "kafka-2-pubsub-cloudbuild"
  display_name = "kafka2pubsub - Service account for running Cloud Build builds"
  depends_on   = [google_project_service.iam]
}

# To-Do: we probably want to narrow this down to just the required permissions,
# including the clouddeploy.released role (https://cloud.google.com/deploy/docs/integrating-ci#calling_from_your_ci_pipeline)
# for creating a Cloud Deploy release after a successful build.
resource "google_project_iam_member" "cloudbuild" {
  project = var.project
  role = "roles/owner"
  member = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_sourcerepo_repository" "source_repo" {
  name       = "kafka-2-pubsub"
  depends_on = [google_project_service.sourcerepo]
}

resource "google_cloudbuild_trigger" "trigger" {
  name            = "kafka-2-pubsub"
  service_account = google_service_account.cloudbuild.id

  trigger_template {
    repo_name   = split("/repos/", google_sourcerepo_repository.source_repo.id)[1]
    branch_name = "master"
  }

  filename   = "cloudbuild.yaml"
  depends_on = [google_project_service.cloudbuild]
}

resource "google_clouddeploy_target" "prod" {
  location = var.region
  name     = "kafka-2-pubsub-prod"

  gke {
    cluster = google_container_cluster.cluster.id
  }

  depends_on = [google_project_service.clouddeploy]
}

resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  location = var.region
  name     = "kafka-2-pubsub"

  serial_pipeline {
    stages {
      target_id = "kafka-2-pubsub-prod"
      profiles  = ["prod"]
    }
  }

  depends_on = [google_project_service.clouddeploy]
}
