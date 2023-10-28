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

In this demo, we will trigger our pipelines and build process by leveraging the native webhook feature in Github, and so we will need to start with a Github repo. For this demo we have provided a pacman repo for you to fork (https://github.com/font/pacman), however this will work with any public Github repo. Make sure to keep the repo public when you fork it. 

After this, access repository's `settings` tab. After clicking on the `Settings` tab, select the `Webhooks` tab from the menu on the left-hand side. Select `Add webhook`. For the `Payload URL`, use the value generated from the script in this directory: `./get-webhook-payload.sh`

Next, set the `Content type` to `application/json` and enter a `Secret` for the webhook. Make sure to save this value for the webhook secret, a script has been written for the next section to help you generate a valid kubernetes secret for it.

### 3. Apply the verify source code pipeline manifests

Change your working directory to `01_verify_source_code_pipeline`. In this directory run the `./generate-webhook-secret-and-customize-manifests.sh` to generate the kubernetes secret, and update the manifests for you chosen github repo and sigstore deployment routes.

After making these two adjustments, you can build the kustomization overlay and apply those files as we did above: `oc apply --kustomize ./` (from `01_verify_source_code_pipeline` as the working directory).

### 4. Setting git configs

The required local git configurations and environment variables can be set by runnign the `set-local-env` script as such: `./set-local-env.sh`. It will give you an option to set some of these configurations locally rather than globally, as it can be rather invasive to sign every commit for every repository with your managed sigstore stack, and even more invasive if you ever have to traverse the rekor log of these commits. If you choose to set these locally, you will need to copy the git configs it gives you to the local copy of the git repo with the webhook.

If everything has been correctly setup, you should be able to sign commits in the usual way (`git commit -m "commit signing message" -S`), which should open up a browser tab where you will authenticate against your OIDC issuer. If your development environment lacks a GUI / browser (such as a bastion or ssh), it will give you a link you can copy into another browser, where you will need to login to keycloak. When you used the `generate-webhook-secret-and-customize-manifests.sh` script, it used the credentials you provided to generate a `keycloak-user.yaml` file in this directory. Use those credentials to login.

If all goes wellyour commit was signed properly, as well as provide you with a TLOG index for your entry in rekor. As discussed in the introduction, this pipeline was meant to model 2 behaviours; firstly, that all commits are properly signed, and secondly, that all these signatures would be available in the designated rekor log. For this purpose, the `verify-commit-signature-task.yaml` contains a significant amount of code to traverse and process entries in the rekor log, since it is rather difficult to search through it for signed git commits specifically. If one does not wish to do this and simply verify commit signatures, you may comment out most of the code in this task (lines 37, 38, 40-107, and 109-113) to install `gitsign` and run `gitsign verify ...`.
