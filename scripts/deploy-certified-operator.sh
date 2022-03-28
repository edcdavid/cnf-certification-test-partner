#!/usr/bin/env bash

# Initialization
SCRIPT_DIR=$(dirname "$0")
source $SCRIPT_DIR/init-env.sh

#check if operator-sdk is installed and install it if needed
if [[ -z "$(which operator-sdk 2>/dev/null)" ]]; then
  echo "operator-sdk executable cannot be found in the path. Will try to install it."
  $SCRIPT_DIR/install-operator-sdk.sh
else
  echo "operator-sdk was found in the path, no need to install it"
fi

# Select namespace based on OCP vs Kind
if $TNF_NON_OCP_CLUSTER
then
	$SCRIPT_DIR/create-redhat-registry-secrets.sh
else
	export CATALOG_NAMESPACE="redhat-marketplace"
fi

# Links the secret to the default service account
oc secrets link default -n $TNF_EXAMPLE_CNF_NAMESPACE redhat-registry-secret --for=pull
oc secrets link default -n $TNF_EXAMPLE_CNF_NAMESPACE redhat-connect-registry-secret --for=pull

# Create the Redhat catalog source
mkdir -p ./temp
cat ./test-target/certified-operator-catalog.yaml | CATALOG_NAMESPACE=$CATALOG_NAMESPACE $SCRIPT_DIR/mo > ./temp/rendered-local-certified-operator-catalog.yaml
oc apply -f ./temp/rendered-local-certified-operator-catalog.yaml
rm ./temp/rendered-local-certified-operator-catalog.yaml

# Create the operator group
mkdir -p ./temp
cat ./test-target/certified-operator-group.yaml | TNF_EXAMPLE_CNF_NAMESPACE=$TNF_EXAMPLE_CNF_NAMESPACE $SCRIPT_DIR/mo > ./temp/rendered-local-certified-operator-group.yaml
oc apply -f ./temp/rendered-local-certified-operator-group.yaml
rm ./temp/rendered-local-certified-operator-group.yaml

# Create the Subscription
mkdir -p ./temp
cat ./test-target/certified-operator-subscription.yaml | CATALOG_NAMESPACE=$CATALOG_NAMESPACE TNF_EXAMPLE_CNF_NAMESPACE=$TNF_EXAMPLE_CNF_NAMESPACE $SCRIPT_DIR/mo > ./temp/rendered-local-certified-operator-subscription.yaml
oc apply -f ./temp/rendered-local-certified-operator-subscription.yaml
rm ./temp/rendered-local-certified-operator-subscription.yaml

while [[ $(sh -c "oc get sa -n$TNF_EXAMPLE_CNF_NAMESPACE| grep $CERTIFIED_OPERATOR_BASE") = ""  ]]; do
	echo "waiting for service account $CERTIFIED_OPERATOR_BASE to appear"
	sleep 5
done
oc secrets link $CERTIFIED_OPERATOR_BASE -n $TNF_EXAMPLE_CNF_NAMESPACE redhat-connect-registry-secret --for=pull
oc scale -n $TNF_EXAMPLE_CNF_NAMESPACE deployment/$CERTIFIED_OPERATOR_BASE --replicas=0
oc scale -n $TNF_EXAMPLE_CNF_NAMESPACE deployment/$CERTIFIED_OPERATOR_BASE --replicas=1

TIMEOUT=24 # 240 seconds
while [[ $(oc get csv -n $TNF_EXAMPLE_CNF_NAMESPACE $CERTIFIED_OPERATOR_NAME -o go-template="{{.status.phase}}") != "Succeeded" && "$TIMEOUT" -gt 0 ]]; do
        echo "waiting for $CERTIFIED_OPERATOR_NAME installation to succeed"
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

# Label the certified operator
oc label clusterserviceversions.operators.coreos.com $CERTIFIED_OPERATOR_NAME -n $TNF_EXAMPLE_CNF_NAMESPACE test-network-function.com/operator=target

