#!/bin/bash

# get tokens
echo "Get real tokens from secrets manager..."
export BROKER_TOKEN=$(gcp-get-secret --verbose --name $BROKER_TOKEN_SECRET)
export JIRA_PASSWORD=$(gcp-get-secret --verbose --name $JIRA_PASSWORD_SECRET)

echo "Run broker..."
broker --verbose