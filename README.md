# kafka-2-pubsub

This demo showcases how to perform a live migration from Kafka to Google Cloud Pub/Sub with minimal downtime.

## Requirements

You need the following in your local environment:

* The Google Cloud CLI, configured with the appropriate credentials to create resources in your GCP project.
* Terraform.
* Docker.
* `kubectl`.

## Deployment

After cloning this repository, run the following command from the root directory:

```bash
make
```

This will invoke the deployment script (`scripts/deploy.sh`), which will do the following:

1. Run some sanity checks to make sure that everything is OK before proceeding.
2. Create some configuration files that depend on your environment variables (and which are not kept under version control).
3. Deploy the Terraform template.
4. Build some of the Docker images used in the demo.
5. Deploy all resources to the Kubernetes cluster.

(You can see all scripts under `scripts/` for further details.)

The above will take about 10 minutes to complete.

## Starting point

If all went good, the script would have deployed this:

![Initial architecture diagram](arch_initial.png)

There's a GKE cluster running the following:

* A standalone Kafka node (the `kafka` service).
* A standalone Zookeeper node (the `zookeeper` service).
* An instance of Kafka Connect (the `kafka-connect` service), configured with [Google Cloud's Pub/Sub connector](https://github.com/GoogleCloudPlatform/pubsub/tree/master/kafka-connector).
* Two producer services (`producer-a` and `producer-b`), which are constantly publishing messages to Kafka.
* Two consumer services (`consumer-a` and `consumer-b`), which are constantly consuming messages from Kafka.

Both producers and consumers are in fact the same demo application, stored under `src/`. In a nutshell, it's a simple Python script that can be configured to either publish or subscribe, and to do so either with Kafka or Pub/Sub. This can be specified via environment variables. Feel free to take a look to understand its inner workings.

Outside of the GKE cluster, the following has already been deployed for you as well:

* A Pub/Sub topic (`kafka-2-pubsub`) with two subscriptions (`kafka-2-pubsub-subscription-a` and `kafka-2-pubsub-subscription-a`).
* An Artifact Registry repository where the custom Docker images are stored. The deployment script will have already push the images for you.
* IAM Service Accounts with the appropriate role bindings in order for everything to work as expected.

## Running the demo

(TBC.)