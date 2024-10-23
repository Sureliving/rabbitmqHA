variable "project" {
  description = "The Google Cloud project ID"
  type        = string
}

provider "google" {
  project = var.project
}

resource "google_compute_network" "shared_vpc" {
  name                    = "shared-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet1" {
  name          = "subnet-first-cluster"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  ip_cidr_range = "10.0.0.0/16"
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.76.0.0/20"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.80.0.0/24"
  }
}

resource "google_compute_subnetwork" "subnet2" {
  name          = "subnet-second-cluster"
  region        = "europe-west2"
  network       = google_compute_network.shared_vpc.id
  ip_cidr_range = "10.1.0.0/16"
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.81.0.0/20"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.85.0.0/24"
  }
}

resource "google_compute_firewall" "allow-pods-and-services" {
  name    = "allow-pods-and-services"
  network = google_compute_network.shared_vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = [
    "10.76.0.0/20",
    "10.80.0.0/24",
    "10.81.0.0/20",
    "10.85.0.0/24" 
  ]
  
  destination_ranges = [
    "10.76.0.0/20",
    "10.80.0.0/24",
    "10.81.0.0/20",
    "10.85.0.0/24"
  ]
}

resource "google_container_cluster" "cluster1" {
  name     = "first-cluster"
  location = "europe-west1"

  network    = google_compute_network.shared_vpc.name
  subnetwork = google_compute_subnetwork.subnet1.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  initial_node_count = 1

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  enable_autopilot = false
}

resource "google_container_cluster" "cluster2" {
  name     = "second-cluster"
  location = "europe-west2"

  network    = google_compute_network.shared_vpc.name
  subnetwork = google_compute_subnetwork.subnet2.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  initial_node_count = 1

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  enable_autopilot = false
}
