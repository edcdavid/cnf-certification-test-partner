if [[ -z "${TNF_PARTNER_NAMESPACE}" ]]; then
    export TNF_PARTNER_NAMESPACE="tnf"
fi

oc delete namespace ${TNF_PARTNER_NAMESPACE}