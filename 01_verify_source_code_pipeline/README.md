# Installing and running the verify source code pipeline

## Introduction

The goal of this pipeline is to verify source code. Its effects are twofold; it will check that changes to your source code are signed and that those signatures appear in the specified instance of the rekor transparency log.

## Pre-requisites

- A healthy openshift cluster with:
    - access to a user with the necessary permissions to create a variety of resources
    - an installation of `Openshift Pipelines`
    - some form of secret management in combination with Gitops (optional but recomended)
    - an installation of a view sigstore components (fulcio, rekor, tuf, and an OIDC provider)
- Binaries on your client machine:
    - `git`
    - `oc`
    - `tkn` (optional, for debugging purposes) 
    - `kustomize` (optional because its built into `oc`)
    - `gitsign` (optional, recommended for testing things on your local system)
    - `jq` or `gojq` (optional, recommended for testing things on your local system)
- A github user with owner rights on the ** public ** repo you wish to build

## Steps

### 1. Apply the base manifests

You can begin by `cloning` down this `git` repository. If you have not already applied the base manifests in the `00_base_pipelines_manifests` directory, navigate there and do that. Make sure to generate the `trusted-artifact-signer-triggerbinding.yaml` using the `generate-tas-triggerbinding.sh` script and then apply the manifests: `oc apply --kustomize ./` (with `00_base_pipelines_manifests` as the current working directory). If you are unsure about this [refer to the README.md](../00_base_pipelines_manifests/README.md).

### 2. Setting up your Github webhook

In this demo, we will trigger our pipelines and build process by leveraging the native webhook feature in Github. We can begin by navigating to the repo of your application. Above, it was noted that you must have `owner` or `admin` rights on this repository to access the `settings` tab. After clicking on the `Settings` tab, select the `Webhooks` tab from the menu on the left-hand side. Select `Add webhook` if you are deploying from scratch, or alternatively, if you are debugging an existing webhook select that. For the `Payload URL`, enter `https://el-build-and-sign`, followed by your Openshift cluster's base URL. This can be found by doing the following based on a route deployed in the `tuf-system` namespace:
```bash 
tuf_route_name=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $1}')
tuf_route_hostname=$(oc get route -n tuf-system $tuf_route_name -o jsonpath='{.spec.host}')
generic_route_hostname="${tuf_route_hostname:4:${#tuf_route_hostname}}/"
github_webhook_payload_url="https://el-verify-source.$generic_route_hostname"
echo $github_webhook_payload_url
```

 Next, set the `Content type` to `application/json` and enter a `Secret` for the webhook. Make sure to save this value for the webhook secret, a script has been written for the next section to help you generate a valid kubernetes secret for it.

### 3. Apply the verify source code pipeline manifests

Change your working directory to `01_verify_source_code_pipeline`. In this directory run the `./generate-webhook-secret-and-customize-manifests.sh` to generate the kubernetes secret, and update the manifests for you chosen github repo and sigstore deployment routes.

After making these two adjustments, you can build the kustomization overlay and apply those files as we did above: `oc apply --kustomize ./` (from `01_verify_source_code_pipeline` as the working directory).

### 4. Setting git configs

The required local git configurations and environment variables can be set by runnign the `set-local-env` script as such: `. ./set-local-env.sh`

If everything has been correctly setup, you should be able to sign commits in the usual way (`git commit -m "commit signing message" -S`), which should open up a browser tab where you will authenticate against your OIDC issuer, and then confirm that your commit was signed properly, as well as provide you with a TLOG index for your entry in rekor. As discussed in the introduction, this pipeline was meant to model 2 behaviours; firstly, that all commits are properly signed, and secondly, that all these signatures would be available in the designated rekor log. For this purpose, the `verify-commit-signature-task.yaml` contains a significant amount of code to traverse and process entries in the rekor log, since it is rather difficult to search through it for signed git commits specifically. If one does not wish to do this and simply verify commit signatures, you may comment out most of the code in this task (lines 37, 38, 40-107, and 109-113) to install `gitsign` and run `gitsign verify ...`.

Finally, you should verify that `gitsign` recognizes these values and they have been properly set by calling `gitsign --version`. This should spit you out a list of the values set in the `gitsign` configuration, you can use this to help troubleshoot if you are having difficulties configuring gitsign to hook into the other elements of your `trusted-artifact-signer` stack.