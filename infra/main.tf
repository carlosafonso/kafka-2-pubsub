terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.27.0"
    }
  }
}

provider "google" {
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

resource "google_service_account" "kafka" {
  account_id = "kafka-2-pubsub"
}

# To-Do: could be reduced to google_pubsub_topic_iam_member
resource "google_project_iam_member" "kafka_svc_acct" {
  project = var.project
  role = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.kafka.email}"
}

resource "google_compute_instance" "kafka" {
  name = "kafka-2-pubsub"
  machine_type = "n2-standard-2"
  zone = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-focal-v20220615"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnetwork.self_link
  }

  service_account {
    email = google_service_account.kafka.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

  metadata_startup_script = <<-EOF
    ###############################################################################
    # Install Java
    ###############################################################################
    apt update -y
    apt install -y default-jre default-jdk
    java -version
    javac -version

    ###############################################################################
    # Install Kafka
    #
    # (Via https://www.digitalocean.com/community/tutorials/how-to-install-apache-kafka-on-ubuntu-20-04)
    ###############################################################################
    useradd kafka -m -G sudo

    curl "https://archive.apache.org/dist/kafka/2.6.3/kafka_2.13-2.6.3.tgz" -o /tmp/kafka.tgz
    mkdir /opt/kafka && cd $_
    tar -xvzf /tmp/kafka.tgz --strip 1
    chown -R kafka:kafka /opt/kafka

    echo "delete.topic.enable = true" >> /opt/kafka/config/server.properties

    echo "[Unit]
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
User=kafka
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/zookeeper.service

    echo "[Unit]
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
User=kafka
ExecStart=/bin/sh -c '/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties > /tmp/kafka.log 2>&1'
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kafka.service

    systemctl start kafka
    systemctl --no-pager status kafka

    systemctl enable zookeeper
    systemctl enable kafka

    # Allow some time for brokers to become available, otherwise topic creation
    # will fail.
    sleep 10

    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic cps-sink-connector-topic

    ###############################################################################
    # Install Pub/Sub Kafka Connector
    ###############################################################################
    curl -L "https://github.com/GoogleCloudPlatform/pubsub/releases/download/v0.11-alpha/pubsub-kafka-connector.jar" -o /home/kafka/pubsub-kafka-connector.jar

    echo "plugin.path=/home/kafka" >> /opt/kafka/config/connect-standalone.properties

    echo "# Cloud Pub/Sub Kafka Sink Connector Config
# File name: cps-sink-connector.properties
name=CPSSinkConnector
connector.class=com.google.pubsub.kafka.sink.CloudPubSubSinkConnector
tasks.max=10
topics=cps-sink-connector-topic
cps.topic=${google_pubsub_topic.topic.name}
cps.project=${var.project}

value.converter=org.apache.kafka.connect.json.JsonConverter
value.converter.schemas.enable=false" > /home/kafka/cps-sink-connector.properties

    echo "/opt/kafka/bin/connect-standalone.sh /opt/kafka/config/connect-standalone.properties /home/kafka/cps-sink-connector.properties" > /home/kafka/run-pubsub-kafka-connector.sh
    chmod +x /home/kafka/run-pubsub-kafka-connector.sh

    echo "Initialization complete: run sudo -u kafka /home/kafka/run-pubsub-kafka-connector.sh when ready"
  EOF
}
