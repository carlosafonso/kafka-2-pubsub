#!/usr/bin/bash

set -euo pipefail

if [ -z $GOOGLE_CLOUD_PROJECT ]; then
    echo "Environment variable GOOGLE_CLOUD_PROJECT is not set."
    exit 1
else
    echo "Environment variable GOOGLE_CLOUD_PROJECT is set."
fi

which terraform > /dev/null
if [ $? -ne 0 ]; then
    echo "Terraform does not seem to be installed in your system."
    exit 1
else
    echo "Terraform appears to be installed."
fi
