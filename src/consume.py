#!/usr/bin/env python
import argparse
from kafka2pubsub import get_bus, init_logging
import logging


def consume(consumer_name):
    def callback(data):
        logging.info("Received data: %s" % data)

    init_logging()
    logging.info("Consumer '%s' initializing" % consumer_name)

    bus = get_bus()
    bus.subscribe(callback)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Consumes messages from an event bus.')
    parser.add_argument('consumer_name', type=str, help='The name of this consumer.')
    args = parser.parse_args()
    consume(args.consumer_name)