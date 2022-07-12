#!/usr/bin/env python
import argparse
from kafka2pubsub import get_bus, init_logging
import logging
import os
import time
import uuid


def produce(producer_name, env):
    init_logging()
    logging.info("Producer '%s' initializing, environment is '%s'" % (producer_name, env))

    bus = get_bus()

    while True:
        bus.publish({'from': producer_name, 'value': str(uuid.uuid4()), 'env': env})
        logging.info("Message sent")
        time.sleep(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Publishes messages to an event bus.')
    parser.add_argument('producer_name', type=str, help='The name of this producer.')
    args = parser.parse_args()

    env = 'undefined'
    if 'K2PS_ENV' in os.environ:
        env = os.environ['K2PS_ENV']

    produce(args.producer_name, env)
