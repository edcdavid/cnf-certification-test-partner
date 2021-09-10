#!/usr/bin/env bash
set -x

if [[ -z "${TNF_PARTNER_NAMESPACE}" ]]; then
    export TNF_PARTNER_NAMESPACE="tnf"
fi

# Cleanup previous deployment if present
operator-sdk cleanup nginx-operator -n $TNF_PARTNER_NAMESPACE