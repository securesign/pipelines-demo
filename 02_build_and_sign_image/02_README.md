Need to remember to modify the `pipeline` serviceaccount with the ability to use my pullsecret

# Installing and running the build and sign image pipeline

## Introduction

The goal of this pipeline is to build and sign an image leveraging tekton chains, and pushing that image and attestation to quay.

## Pre-requisites

- A healthy openshift cluster with:
    - access to a user with the necessary permissions to create a variety of resources
    - an installation of `Openshift Pipelines`
    - an installation of a view sigstore components (fulcio, rekor, tuf, and an OIDC provider)
- Binaries on your client machine:
    - `git`
    - `oc`
    - `kustomize`
    - `yq`
    - `docker` or `podman` (for testing purposes on your local machine)
- A github user with owner rights on the repo you wish to build
- A Qauy account and repostiory to which the signed image and attestations will be pushed, for the given github repo you wish to build from

## Steps

### 1. Apply the base manifests

As discussed in the repo for the previous pipeline we want to apply the base manifests. If you are confused on how to do this refer to the [`README.md` in the `00_base_pipelines_manifests` directory](../00_base_pipelines_manifests/README.md), but the general concept is that after running the `generate-tas-triggerbinding.sh` script you should be able to apply the manifests: `oc apply --kustomize ./` (with `00_base_pipelines_manifests` as the current working directory).

### 2. Setting up your Github webhook

Much like the previous pipeline, we will also use a Github webhook to kick off the build process. Refer to the previous [README file for the previous pipeline](../01_verify_source_code_pipeline/README.md) if you have any questions. Use the value of the following script for your `Payload URL`:

```bash
tuf_route_name=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $1}')
tuf_route_hostname=$(oc get route -n tuf-system $tuf_route_name -o jsonpath='{.spec.host}')
generic_route_hostname="${tuf_route_hostname:4:${#tuf_route_hostname}}/"
github_webhook_payload_url="https://el-build-and-sign.$generic_route_hostname"
echo $github_webhook_payload_url
```

It should be noted that you cannot reuse the Github webhook for the previous pipeline, it either needs to be a new webhook in the same repo, or a webhook in a seperate repo.


### 3. Configure the Quay repository

#### Create or verify that the Quay repo exists

First you should verify that a quay repository has been setup for storing the signed images built from your github repo source code. If this has not been created, procede to create one.

#### Setting up the robot account and deploying the pull-secret

First navigate to your Quay account, and select `Account settings` from the dropdown of your user. Click the middle option to go to the `Robot Accounts` menu. If you already have a robot account that you wish to use for the building and pushing of the images, you can skip this step. If not go through the `Create Robot Account` menu, by providing it a name and description. Click on the `options` wheel icon on the right hand side, for the newly created robot account, and then select `Set Repository Permissions`. Find the Quay repo mentioned above, and give this robot account `write` permissions on that repository. After you have updated the permissions, select `View Credentials` from the same `options` wheel icon at the right edge of the screen, and then download the yaml file for the secret (left option) from the `Kuberenetes Secret` menu. You should then apply this `pull-secret` to the `securesign-pipelines-demo` namespace we have been working in: `oc apply -f ~/Downloads/<downloaded-secret-name>.yaml -n securesign-pipelines-demo`.

#### Enable the `pipeline` ServiceAccount to be able to use the pull-secret

With a proper installation of `openshift-pipelines`, every namespace should have a `pipeline` `ServiceAccount` for it. This is the default `ServiceAccount` that pipelines will use in that namespace. Since we use that `pipeline` `ServiceAccount` in the `build-and-sign-pipeline`, we want to make sure that it has access to the pull-secret we downloaded and applied to the cluster, so that it has the permissions to push to your quay repository. Pull down the `pipeline` `ServiceAccount` as a yaml file: ` oc get serviceaccount pipeline -n securesign-pipelines-demo -o yaml > pipeline-service-account.yaml`. After this add an entry with the name of your `pull-secret` as both a `secret` and an `imagePullSecret`. After this re-deploy the `ServiceAccount` to update its changes: `oc apply -f ./pipeline-service-account.yaml`, which should allow that service account to now push to your Quay repo.

### 4. customize and apply the manifests

As before, a script has been provided to streamline this process:

```bash
./gerenate-webhook-secret-and-customize-manifsts.sh
oc apply --kustomize ./
```

### 5. Starting the pipeline

If everything has been configured properly, any code changes that have been commited and pushed to github will trigger the pipeline and start the image build process.
