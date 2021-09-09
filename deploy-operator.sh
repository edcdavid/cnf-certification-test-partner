set x

# Deploy the operator bundle
operator-sdk run bundle cnftest-local.redhat.com/nginx-operator-bundle:v0.0.1 --ca-secret-name foo-cert-sec -n $TNF_PARTNER_NAMESPACE
