#!/bin/bash
# Launch Kafka Connect
/etc/confluent/docker/run &

# Wait for Kafka Connect listener
echo "Waiting for Kafka Connect to start listening on localhost ⏳"
while : ; do
  curl_status=$(curl -s -o /dev/null -w %{http_code} http://localhost:8083/connectors)
  echo -e $(date) " Kafka Connect listener HTTP state: " $curl_status " (waiting for 200)"
  if [ $curl_status -eq 200 ] ; then
    break
  fi
  sleep 5
done

echo -e "\n--\n+> Creating Data Generator source"
curl -s \
    -X PUT \
    -H  "Content-Type:application/json" http://localhost:8083/connectors/PubSubConnector/config \
    -d @/tmp/pubsub-connector.json

# Ensure we caught SIGINTs and SIGTERMs so we can propagate them downstream.
/bin/sh -c trap : TERM INT; sleep infinity & wait
