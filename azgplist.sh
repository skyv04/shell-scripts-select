#!/bin/bash

set -e

# Check if subscription argument is provided
if [ -z "$1" ]
  then
    echo "Subscription argument is missing"
    exit 1
fi


# List the resource groups
az group list --subscription $1  --output table
