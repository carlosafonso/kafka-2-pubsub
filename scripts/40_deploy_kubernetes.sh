#!/usr/bin/bash

set -euo pipefail

gcloud container clusters get-credentials kafka-2-pubsub --region us-central1
kubectl apply -f infra/k8s/kafka.yaml
