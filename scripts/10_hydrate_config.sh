#!/usr/bin/bash

set -euo pipefail

envsubst < ./infra/k8s/kafka.yaml.dist > ./infra/k8s/kafka.yaml
envsubst < ./kafka-connect/pubsub-connector.json.dist > ./kafka-connect/pubsub-connector.json
