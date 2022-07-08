#!/usr/bin/bash

set -euo pipefail

envsubst < ./infra/k8s/kafka.yaml.dist > ./infra/k8s/kafka.yaml
envsubst < ./kafka-connect/pubsub-connector.json.dist > ./kafka-connect/pubsub-connector.json

cat > ./infra/terraform.tfvars <<-EOF
    project = "${GOOGLE_CLOUD_PROJECT}"
    region = "us-central1"
    zone = "us-central1-a"
EOF
