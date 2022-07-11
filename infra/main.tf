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

resource "google_compute_network" "vpc" {
  name                    = "kafka-2-pubsub"
  auto_create_subnetworks = "false"
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
  name = "kafka-2-pubsub"
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
  provider = google-beta
  location = var.region
  repository_id = "kafka-2-pubsub"
  format = "DOCKER"
}

resource "google_service_account" "gke" {
  account_id   = "kafka-2-pubsub-gke"
  display_name = "kafka2pubsub - Service account for the GKE cluster that allows it to interact with Pub/Sub"
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
  name = "kafka-2-pubsub"
  location = var.region
  network = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnetwork.self_link

  remove_default_node_pool = true
  initial_node_count = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}
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