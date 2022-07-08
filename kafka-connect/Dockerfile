FROM ubuntu AS build
RUN apt-get -y update && apt-get install -y curl
RUN curl -L "https://github.com/GoogleCloudPlatform/pubsub/releases/download/v0.11-alpha/pubsub-kafka-connector.jar" -o /tmp/pubsub-kafka-connector.jar

FROM confluentinc/cp-kafka-connect:7.1.2
COPY --from=build /tmp/pubsub-kafka-connector.jar /usr/share/java/kafka/pubsub-kafka-connector.jar
COPY pubsub-connector.json /tmp/pubsub-connector.json
COPY startup.sh /usr/bin/startup.sh
