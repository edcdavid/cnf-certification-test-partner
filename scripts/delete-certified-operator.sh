#!/usr/bin/env bash

# Initialization
SCRIPT_DIR=$(dirname "$0")
source $SCRIPT_DIR/init-env.sh

# delete CSV
oc delete csv kong.v0.10.0 -n $TNF_EXAMPLE_CNF_NAMESPACE

# delete operator group
oc delete operatorgroups test-group -n $TNF_EXAMPLE_CNF_NAMESPACE

# delete subscription
oc delete subscriptions test-subscription -n $TNF_EXAMPLE_CNF_NAMESPACE

# delete catalog source
oc delete catalogsources test-catalog -n $TNF_EXAMPLE_CNF_NAMESPACE