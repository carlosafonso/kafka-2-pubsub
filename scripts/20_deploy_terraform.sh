#!/usr/bin/env bash

set -euo pipefail

terraform -chdir=infra/ init
terraform -chdir=infra/ apply -auto-approve
