# Simplified steps:

#Base manifests

cd 00_base_pipelines_manifests
./generate-tas-triggerbinding.sh
oc apply --kustomize ./

# Pipeline 1

cd ../01_verify_source_code_pipeline

tuf_route_name=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $1}')
tuf_route_hostname=$(oc get route -n tuf-system $tuf_route_name -o jsonpath='{.spec.host}')
generic_route_hostname="${tuf_route_hostname:4:${#tuf_route_hostname}}/"
github_webhook_payload_url="https://el-verify-source.$generic_route_hostname"
echo $github_webhook_payload_url

<< setup_webhook
Create a Github webhook (go to repository in github ui, click Settings --> Webhook --> Add webhook)
Set the following values:
    Payload URL will be the result of the preceding block of code, what is contained in the $github_webhook_payload_url environment variable and should be printed to your terminal
    Content type = application/json
    Secret: Enter whatever you want for your secret but save the value, it will be needed by the following script
    Which events would you like to trigger this webhook? = Just the push event
    Active = checked (We will deliver event details when this hook is triggered.)
Create the webhook
setup_webhook

./generate-webhook-secret-and-customize-manifests.sh

. ./set-local-env.sh

oc apply --kustomize ./

# Pipeline 2

cd ../02_build_and_sign_image

tuf_route_name=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $1}')
tuf_route_hostname=$(oc get route -n tuf-system $tuf_route_name -o jsonpath='{.spec.host}')
generic_route_hostname="${tuf_route_hostname:4:${#tuf_route_hostname}}/"
github_webhook_payload_url="https://el-build-and-sign.$generic_route_hostname"
echo $github_webhook_payload_url

<< setup_webhook
Create a Github webhook (go to repository in github ui, click Settings --> Webhook --> Add webhook)
Set the following values:
    Payload URL will be the result of the preceding block of code, what is contained in the $github_webhook_payload_url environment variable and should be printed to your terminal
    Content type = application/json
    Secret: Enter whatever you want for your secret but save the value, it will be needed by the following script
    Which events would you like to trigger this webhook? = Just the push event
    Active = checked (We will deliver event details when this hook is triggered.)
Create the webhook
setup_webhook
