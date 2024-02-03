#!/bin/bash

# Get all subscriptions
subscriptions=$(az account list --query '[].{name:name, id:id}' --output tsv)

# Loop through each subscription
while read -r subscription; do
    # Extract subscription ID and name
    subscription_id=$(echo $subscription | awk '{print $2}')
    subscription_name=$(echo $subscription | cut -f2- -d' ')

    # Set the subscription context
    az account set --subscription $subscription_id

    # List all the subscription IDs and names
    echo "Subscription ID: $subscription_id, Subscription Name: $subscription_name"
done <<< "$subscriptions"

