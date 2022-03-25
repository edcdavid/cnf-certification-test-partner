#!/usr/bin/env bash

# Initialization
SCRIPT_DIR=$(dirname "$0")
source $SCRIPT_DIR/init-env.sh

# Links the secret to the default service account
oc secrets link default -n $TNF_EXAMPLE_CNF_NAMESPACE 11009103-tnfsuite-pull-secret --for=pull

# Create the Redhat catalog source
mkdir -p ./temp
cat ./test-target/certified-operator-catalog.yaml | TNF_EXAMPLE_CNF_NAMESPACE=$TNF_EXAMPLE_CNF_NAMESPACE $SCRIPT_DIR/mo > ./temp/rendered-local-certified-operator-catalog.yaml
oc apply -f ./temp/rendered-local-certified-operator-catalog.yaml
rm ./temp/rendered-local-certified-operator-catalog.yaml


# Create the operator group
mkdir -p ./temp
cat ./test-target/certified-operator-group.yaml | TNF_EXAMPLE_CNF_NAMESPACE=$TNF_EXAMPLE_CNF_NAMESPACE $SCRIPT_DIR/mo > ./temp/rendered-local-certified-operator-group.yaml
oc apply -f ./temp/rendered-local-certified-operator-group.yaml
rm ./temp/rendered-local-certified-operator-group.yaml


# Create the Subscription
mkdir -p ./temp
cat ./test-target/certified-operator-subscription.yaml | TNF_EXAMPLE_CNF_NAMESPACE=$TNF_EXAMPLE_CNF_NAMESPACE $SCRIPT_DIR/mo > ./temp/rendered-local-certified-operator-subscription.yaml
oc apply -f ./temp/rendered-local-certified-operator-subscription.yaml
rm ./temp/rendered-local-certified-operator-subscription.yaml

while [[ $(sh -c "oc get sa -n$TNF_EXAMPLE_CNF_NAMESPACE| grep kong-operator") = ""  ]]; do
	echo "waiting for service account kong-operator to appear"
	sleep 5
done
oc secrets link kong-operator -n $TNF_EXAMPLE_CNF_NAMESPACE redhat-connect-registry-secret --for=pull
oc scale -n $TNF_EXAMPLE_CNF_NAMESPACE deployment/kong-operator --replicas=0
oc scale -n $TNF_EXAMPLE_CNF_NAMESPACE deployment/kong-operator --replicas=1

TIMEOUT=24 # 240 seconds
while [[ $(oc get csv -n$TNF_EXAMPLE_CNF_NAMESPACE kong.v0.10.0 -o go-template="{{.status.phase}}") != "Succeeded" && "$TIMEOUT" -gt 0 ]]; do
        echo "waiting for kong operator installation to succeed"
        sleep 10
	TIMEOUT=$(($TIMEOUT-1))
	echo $TIMEOUT
done

if [ "$TIMEOUT" -le 0  ]; then
	echo "timed out waiting for the operator to succeed"
	oc get csv -n $TNF_EXAMPLE_CNF_NAMESPACE
	exit 1
fi

oc get csv -n $TNF_EXAMPLE_CNF_NAMESPACE
