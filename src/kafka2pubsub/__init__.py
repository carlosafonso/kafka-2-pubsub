from google.cloud import pubsub_v1
from kafka import KafkaConsumer, KafkaProducer
import json
import logging
import os


def init_logging():
    logging.basicConfig(level=logging.INFO)


def get_bus():
    if 'K2PS_BUS_BACKEND' not in os.environ:
        raise Exception('Environment variable "K2PS_BUS_BACKEND" not set')

    if os.environ['K2PS_BUS_BACKEND'] == 'kafka':
        return get_kafka_bus()
    elif os.environ['K2PS_BUS_BACKEND'] == 'pubsub':
        return get_pubsub_bus()

    raise Exception('Environment variable "K2PS_BUS_BACKEND" must be either "kafka" or "pubsub"')


def get_kafka_bus():
    if 'K2PS_KAFKA_TOPIC' not in os.environ:
        raise Exception('Environment variable "K2PS_KAFKA_TOPIC" not set')
    if 'K2PS_KAFKA_BOOTSTRAP_SERVER' not in os.environ:
        raise Exception('Environment variable "K2PS_KAFKA_BOOTSTRAP_SERVER" not set')

    return KafkaEventBus(os.environ['K2PS_KAFKA_TOPIC'], os.environ['K2PS_KAFKA_BOOTSTRAP_SERVER'])


def get_pubsub_bus():
    if 'K2PS_PUBSUB_TOPIC' not in os.environ:
        raise Exception('Environment variable "K2PS_PUBSUB_TOPIC" not set')
    if 'K2PS_PUBSUB_SUBSCRIPTION' not in os.environ:
        raise Exception('Environment variable "K2PS_PUBSUB_SUBSCRIPTION" not set')

    return PubSubEventBus(os.environ['K2PS_PUBSUB_TOPIC'], os.environ['K2PS_PUBSUB_SUBSCRIPTION'])


class PubSubEventBus(object):
    def __init__(self, topic_name, subscription_name):
        self._topic_name = topic_name
        self._subscription_name = subscription_name
        self._p = pubsub_v1.PublisherClient()
        self._s = pubsub_v1.SubscriberClient()

    def publish(self, data):
        data["bus"] = "pubsub"
        logging.info("Sending message via Pub/Sub: %s" % json.dumps(data))
        future = self._p.publish(self._topic_name, json.dumps(data).encode('utf-8'))
        future.result()

    def subscribe(self, callback):
        def on_message_received(message):
            logging.info("Received message via Pub/Sub, invoking callback...")
            callback(message.data)
            message.ack()
            logging.info("Callback succeeded, message has been acknowledged")

        with self._s as subscriber:
            future = subscriber.subscribe(self._subscription_name, on_message_received)
            try:
                future.result()
            except KeyboardInterrupt:
                future.cancel()


class KafkaEventBus(object):
    def __init__(self, topic_name, bootstrap_server):
        logging.info("Initializing KafkaEventBus with topic name '%s' and bootstrap server '%s'" % (topic_name, bootstrap_server))
        self._topic_name = topic_name
        self._p = KafkaProducer(bootstrap_servers=[bootstrap_server])
        self._c = KafkaConsumer(topic_name, bootstrap_servers=[bootstrap_server])

    def publish(self, data):
        data["bus"] = "kafka"
        logging.info("Sending message via Kafka: %s" % json.dumps(data))
        self._p.send(self._topic_name, json.dumps(data).encode('utf-8'))
        self._p.flush()

    def subscribe(self, callback):
        for msg in self._c:
            logging.info("Received message via Kafka, invoking callback...")
            callback(msg.value)
            logging.info("Callback succeeded")
