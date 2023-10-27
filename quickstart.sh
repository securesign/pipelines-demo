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
<<<<<<< HEAD
=======


<< setup_quay
Step 1: First verify or create a quay repository for holding the images

Step 2: Setting up the robot account and deploying the pull-secret
1. Quay account --> 2. Account settings --> 3. Robot Accounts --> 4. Create Robot Account --> 5. fill out name and description --> 
6. click options (wheel icon right hand side) --> 7. Set Repository Permissions --> 8. Give ** WRITE ** permissions on the quay repo you previously created --> 
9. View Credentials (from options wheel icon right hand side) --> 10. Kubernetes Secret -->  11. download yaml file (left option) -->
12. apply secret: \`oc apply -f ~/Downloads/<downloaded-secret-name>.yaml -n securesign-pipelines-demo\`

setup_quay

#### Enable the `pipeline` ServiceAccount to be able to use the pull-secret

With a proper installation of `openshift-pipelines`, every namespace should have a `pipeline` `ServiceAccount` for it. This is the default `ServiceAccount` that pipelines will use in that namespace. Since we use that `pipeline` `ServiceAccount` in the `build-and-sign-pipeline`, we want to make sure that it has access to the pull-secret we downloaded and applied to the cluster, so that it has the permissions to push to your quay repository. Pull down the `pipeline` `ServiceAccount` as a yaml file: ` oc get serviceaccount pipeline -n securesign-pipelines-demo -o yaml > pipeline-service-account.yaml`. After this add an entry with the name of your `pull-secret` as both a `secret` and an `imagePullSecret`. After this re-deploy the `ServiceAccount` to update its changes: `oc apply -f ./pipeline-service-account.yaml`, which should allow that service account to now push to your Quay repo.
>>>>>>> 6598d07 (adding automation)
