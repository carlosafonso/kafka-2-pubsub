#!/usr/bin/bash

set -euo pipefail

docker build -t kafka-2-pubsub src/
docker tag kafka-2-pubsub:latest "us-central1-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/kafka-2-pubsub/kafka-2-pubsub:latest"
docker push "us-central1-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/kafka-2-pubsub/kafka-2-pubsub:latest"

docker build -t kafka-connect kafka-connect/
docker tag kafka-connect:latest "us-central1-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/kafka-2-pubsub/kafka-connect:latest"
docker push "us-central1-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/kafka-2-pubsub/kafka-connect:latest"