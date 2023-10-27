#!/bin/bash

# Part 1: Setup Github Webhook

read -s -p "Enter the secret value used to setup the Github webhook: " webhook_secret

oc create secret generic webhook-secret-build-and-sign-pipeline-demo --from-literal=webhook-secret-key=$webhook_secret -n securesign-pipelines-demo

# Part 2: Modify `pipeline` `ServiceAccount` to use quay pull-secret

echo "Please identify the Kubernetes secret you created for your quay pull-secret. Here are the secrets in the securesign-pipelines-demo namespace: "
oc get secret -n securesign-pipelines-demo
read -p "Enter the name of the correct pull-secret (if it is not here enter nothing): " pull_secret_name

if [[ -z $pull_secret_name ]]; then
  echo "Seems you did not apply the pull-secret to the cluster. Please verify you created the secret in the correct namespace (securesign-pipelines-demo) and try again. Refer to the README.md file for more info."
  exit 1
fi

get_secret=$(oc get secret $pull_secret_name -n securesign-pipelines-demo)
if [[ -z $get_secret ]]; then
  echo "secret was not found in namespace.  Please verify you created the secret in the correct namespace (securesign-pipelines-demo) and try again. Refer to the README.md file for more info."
  exit 1
fi;

echo "
Copy your the name of your pull-secret now. 
Add the name of your pull-secret to the imagePullSecrets and secrets section of the following service account.
Once you have coppied the secret name, press any key to continue."

sleep 5

read -s -n 1 key

oc edit serviceaccount pipeline -n securesign-pipelines-demo
# Part 3: Customize pipeline manifests

read -p "Enter the case sensitive github organization and repo combination (ex: 'securesign/pipelines-demo'): " github_org_and_repo

read -p "Enter the quay image repository to push these built images to (ex: 'quay.io/grpereir/pacman'): " quay_repo

server_api_url=$(oc whoami --show-server)
host_plus_port="el-build-and-sign.apps.${server_api_url:12:${#server_api_url}}"
host_plus_port_length=${#host_plus_port}
host="${host_plus_port:0:$((host_plus_port_length - 5))}"

echo "apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: el-build-and-sign
spec:
  host: $host
  port:
    targetPort: http-listener
  to:
    kind: Service
    name: el-build-and-sign
    weight: 100
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None" > ./build-and-sign-el-route.yaml


echo "apiVersion: triggers.tekton.dev/v1alpha1
kind: EventListener
metadata:
  name: build-and-sign
spec:
  resources:
    kubernetesResource:
      replicas: 1
  serviceAccountName: pipeline
  triggers: 
    - bindings:
        - kind: TriggerBinding
          ref: github-push-triggerbinding
        - kind: TriggerBinding
          ref: build-and-sign-triggerbinding
      interceptors:
        - params:
            - name: secretRef
              value:
                secretKey: webhook-secret-key
                secretName: webhook-secret-build-and-sign-pipeline-demo
          ref:
            kind: ClusterInterceptor
            name: github
        - params:
            - name: filter 
              value: >-
                (header.match('X-GitHub-Event', 'push') &&
                body.repository.full_name == '$github_org_and_repo')
            - name: overlays
              value:
                - expression: 'body.ref.split(''/'')[2]'
                  key: ref
          ref:
            kind: ClusterInterceptor
            name: cel
      name: build-and-sign-triggertemplate
      template: 
        ref: build-and-sign-triggertemplate" > ./build-and-sign-el.yaml

echo "apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: build-and-sign-triggerbinding
spec:
  params:
  - name: tlsVerify 
    value: true
  - name: imageRepo
    value: $quay_repo
  - name: gitRepoHost 
    value: github.com" > ./build-and-sign-triggerbinding.yaml

rekor_url=$(oc get routes -n rekor-system | grep 'rekor' | awk '{print $2}')
fulcio_url=$(oc get routes -n fulcio-system | grep 'fulcio-server-http' | awk '{print $2}')

echo "apiVersion: operator.tekton.dev/v1alpha1
kind: TektonChain
metadata:
  name: chain
spec:
  targetNamespace: openshift-pipelines
  artifacts.oci.format: simplesigning
  artifacts.oci.storage: oci
  artifacts.oci.signer: x509
  artifacts.taskrun.format: in-toto 
  artifacts.taskrun.storage: oci
  artifacts.taskrun.signer: x509
  transparency.enabled: true
  transparency.url: https://$rekor_url
  signers.x509.fulcio.enabled: true
  signers.x509.fulcio.address: https://$fulcio_url" > ./tektonChain.yaml

rm ./pipeline-service-account.yaml

echo "success!"
exit 0