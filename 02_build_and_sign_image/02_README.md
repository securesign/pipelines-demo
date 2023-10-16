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
    - `docker` or `podman` (for testing purposes on your local machine)
- A github user with owner rights on the repo you wish to build
- A Qauy account and repostiory to which the signed image and attestations will be pushed, for the given github repo you wish to build from

## Steps

### 1. Apply the base manifests

As discussed in the repo for the previous pipeline we want to apply the base manifests. If you are confused on how to do this refer to the `README.md` in the `01_verify_soruce_code_pipeline` directory, but the command should be `kustomize build ./ | oc apply -f -` (from `00_base_pipelines_manifests` as the working directory).

### 2. Setting up your Github webhook

Much like the previous pipeline, we will also use a Github webhook to kick off the build process. To breifly sumarize the process for the previous pipeline, you access the `settings` tab on the repository,  then select the `Webhooks` tab from the menu, and then select `Add webhook`. As before set the `Payload URL`, but this time enter `https://el-build-and-sign`, followed by your Openshift cluster's base domain. Add a passcode for the webhook in the `Secret` field, and then backup that data into a valid Kubernetes secret that is deployed into the `securesign-pipelines-demo` `namepsace` or whatever you have changed that value to. Refer to the previous [README file for the previous pipeline](../01_verify_source_code_pipeline/README.md) if you have any questions.


### 3. Configure Tekton Chains

If you look at the manifests in the `02_build_and_sign_image` directory, you will notice that the `build-and-sign-pipeline.yaml` file is actually a very basic pipeline, with only tasks for pulling source code and building / signing images. This is because the pipeline leverages Tekton chains to do the signing behind the scenes, allowing this build and sign task to be an implementation of the `buildah` `ClusterTask`. After navigating to the `02_build_and_sign_image` directory, ensure that the `targetNamespace` value in the `tektonChain.yaml` file (on line 6) matches the namespace in which openshift-pipelines was installed. Finally, you can install Tekton Chains by simply applying the configuration file in this directory: `oc apply -f tektonChain.yaml`.

### 4. Configure the Quay repository

#### Create or verify that the Quay repo exists

First you should verify that a quay repository has been setup for storing the signed images built from your github repo source code. If this has not been created, procede to create one.

#### Setting up the robot account and deploying the pull-secret

First navigate to your Quay account, and select `Account settings` from the dropdown of your user. Click the middle option to go to the `Robot Accounts` menu. If you already have a robot account that you wish to use for the building and pushing of the images, you can skip this step. If not go through the `Create Robot Account` menu, by providing it a name and description. Click on the `options` wheel icon on the right hand side, for the newly created robot account, and then select `Set Repository Permissions`. Find the Quay repo mentioned above, and give this robot account `write` permissions on that repository. After you have updated the permissions, select `View Credentials` from the same `options` wheel icon at the right edge of the screen, and then download the yaml file for the secret (left option) from the `Kuberenetes Secret` menu. You should then apply this `pull-secret` to the `securesign-pipelines-demo` namespace we have been working in: `oc apply -f ~/Downloads/<downloaded-secret-name>.yaml -n securesign-pipelines-demo`.

#### Enable the `pipeline` ServiceAccount to be able to use the pull-secret

With a proper installation of `openshift-pipelines`, every namespace should have a `pipeline` `ServiceAccount` for it. This is the default `ServiceAccount` that pipelines will use in that namespace. Since we use that `pipeline` `ServiceAccount` in the `build-and-sign-pipeline`, we want to make sure that it has access to the pull-secret we downloaded and applied to the cluster, so that it has the permissions to push to your quay repository. Pull down the `pipeline` `ServiceAccount` as a yaml file: ` oc get serviceaccount pipeline -n securesign-pipelines-demo -o yaml > pipeline-service-account.yaml`. After this add an entry with the name of your `pull-secret` as both a `secret` and an `imagePullSecret`. After this re-deploy the `ServiceAccount` to update its changes: `oc apply -f ./pipeline-service-account.yaml`, which should allow that service account to now push to your Quay repo.

### 5. Apply the verify source code pipeline manifests

Starting from the `02_build_and_sign_image` directory we need to make sure the values here match the configuration you wish to set.

- Update the `host` value in the `build-and-sign-el-route.yaml` to deploy a valid route for the event listener to your cluster (pass your cluster base domain after the route name).

- As with the previous pipeline, update the repository `full_name` value on line 31 of the `build-and-sign-el.yaml` file, to match the github repo you wish to build your application from.

- Verify that you previously created a kubernetes secret for the webhook passcode for this new repository, and that it is properly referenced in the `build-and-sign-el.yaml` eventlistner on lines 20-23.

- Make sure that the webhook secret is correctly referencing the kuberenetes secret you created for it on lines 20-23 of the `build-and-sign-el.yaml`

- Enter your quay repository as the value of the `imageRepo` parameter in the `build-and-sign-triggerbinding.yaml` on line 10

- Verify that you have correctly passed your `pull-secret` to the `PipelineRun` on lines 100-103 of the `build-and-sign-triggertemplate.yaml`.

Once all these modifications have been made, you may build the files from the kustomization file and deploy them: `kustomize build ./ | oc apply -f -` (from `02_build_and_sign_image` as the working directory).


### 6. Starting the pipeline

If everything has been configured properly, any code changes that have been commited and pushed to github will trigger the pipeline and start the image build process.
