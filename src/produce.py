#!/usr/bin/env python
import argparse
from kafka2pubsub import get_bus, init_logging
import logging
import time
import uuid


def produce(producer_name):
    init_logging()
    logging.info("Producer '%s' initializing" % producer_name)

    bus = get_bus()

    while True:
        bus.publish({'from': producer_name, 'value': str(uuid.uuid4())})
        logging.info("Message sent")
        time.sleep(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Publishes messages to an event bus.')
    parser.add_argument('producer_name', type=str, help='The name of this producer.')
    args = parser.parse_args()
    produce(args.producer_name)
