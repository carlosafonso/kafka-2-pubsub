#!/usr/bin/bash

set -euo pipefail

kubectl apply -f infra/k8s/kafka.yaml
