#!/usr/bin/env python
import argparse
from kafka2pubsub import get_bus, init_logging
import logging
import os


def consume(consumer_name, env):
    def callback(data):
        logging.info("Received data: %s" % data)

    init_logging()
    logging.info("Consumer '%s' initializing, environment is '%s'" % (consumer_name, env))

    bus = get_bus()
    bus.subscribe(callback)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Consumes messages from an event bus.')
    parser.add_argument('consumer_name', type=str, help='The name of this consumer.')
    args = parser.parse_args()

    env = 'undefined'
    if 'K2PS_ENV' in os.environ:
        env = os.environ['K2PS_ENV']

    consume(args.consumer_name, env)
