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
    - `kustomize`
    - `gitsign` (optional, recommended for testing things on your local system)
    - `jq` or `gojq` (optional, recommended for testing things on your local system)
- A github user with owner rights on the repo you wish to build

## Steps

### 1. Apply the base manifests

You can begin by `cloning` down this `git` repository. From this repo's root directory, navigate to the `00_base_pipelines_manifests` directory, which contain resources used by every one of these pipelines. Optionally, you can modify the `namespace` to be whatever you like, but if it gets changed, keep this consistent by changing this value on all other manifests in this repository. Additionally, edit the `trusted-artifact-signer-triggerbiding.yaml`, swapping out the routes to the resources in your sigstore instance with the current values. If there is anything that you don't recognize or understand, see our documentation on setting up your own sigstore instance (INSERT LINK).

These are the following values that you will need, and the Bash commands you can run to get them (assumes installed using `tas-easy-install.sh` in `sigstore-ocp` repo with default installation of keycloak as oidc provider):

- `rekor-url`: `rekor_url=$(oc get routes -n rekor-system | grep 'rekor' | awk '{print $2}')/`
- `issuer-url`: `issuer_url=$(oc get routes -n keycloak-system | grep 'keycloak' | awk '{print $2}')/auth/realms/sigstore`
- `fulcio-url`: `fulcio_url=$(oc get routes -n fulcio-system | grep 'fulcio-server-http' | awk '{print $2}')/`
- `tuf-mirror`: `tuf_mirror=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $2}')/`
- `fulcio-crt-pem-url`: `fulcio_crt_pem_url=${tuf_mirror}targets/fulcio_v1.crt.pem`
- `tuf-root`: `tuf_root=${tuf-mirror}root.json`
- `rekor-public-key`: `rekor_public_key=${tuf_mirror}targets/rekor.pub`
- `ctfe-public-key`: `ctfe_public_key=${tuf_mirror}targets/ctfe.pub`


After modifying the `trusted-artifact-signer-triggerbiding.yaml`, apply all these manifests to your cluster using `kustomize` and `oc`: `kustomize build ./ | oc apply -f -` (from `00_base_pipelines_manifests` as the working directory).

### 2. Setting up your Github webhook

In this demo, we will trigger our pipelines and build process by leveraging the native webhook feature in Github. We can begin by navigating to the repo of your application. Above, it was noted that you must have `owner` or `admin` rights on this repository to access the `settings` tab. After clicking on the `Settings` tab, select the `Webhooks` tab from the menu on the left-hand side. Select `Add webhook` if you are deploying from scratch, or alternatively, if you are debugging an existing webhook select that. For the `Payload URL`, enter `https://el-build-and-sign`, followed by your Openshift cluster's base URL. This base route should begin with `apps.`, and you should be able to find it by navigating to your openshift console, and copying everything after `console-openshift-console` in the URL, up until the domain extension (usually `.com`). If my clusters base URL was `apps.trusted-artifact-signer-test.redhat.com`, then this `Payload URL` should be: `https://el-build-and-sign.apps.trusted-artifact-signer-test.redhat.com`. Next, set the `Content type` to `application/json` and enter a `Secret` for the webhook. After doing this, create a Kubernetes secret containing the secret passcode for the webhook.

### 3. Apply the verify source code pipeline manifests

Change your working directory to `01_verify_source_code_pipeline`. In this directory, you will notice the `webhook-sealed-secret-securesign-pipelines-demo.yaml` file, which contains the value of our webhook secret in the form of a `sealed-secret`. Sealed secrets are not a necesity for running this pipeline, this is just how we have chosen to manage  a secret in the context of a gitops repository. Regardless of the format, make sure there is a valid Kubernetes secret containing the passcode for the webhook, that it is referenced as a `resource` in the `kustomization.yaml` file, and that this secret has been passed to the eventlistnener (in the `verify-source-el.yaml` on lines 18-21).

Additionally, the eventlistener uses a `cel` `filter` `ClutsterInterceptor` to target certain events only. You must modify the repository `full_name` value (in the `verify-source-el.yaml` on lines 29) to match the GitHub repo you wish to build from. It should be noted that this `org/repo` combinaiton is case sensitive.

You will also need to swap out the value for the `host` in the `verify-source-code-el-route.yaml` to match your cluster.

After making these two adjustments, you can build the kustomization overlay and apply those files as we did above: `kustomize biuld ./ | oc apply -f -` (from `01_verify_source_code_pipeline` as the working directory).

### 4. Setting git configs

Until now, we have created the manifests and resources for starting the pipeline from a push event from a GitHub webhook. However, now we need to make sure the commits are being signed properly such that when the pipeline is triggered, it can validate these entries against the rekor log and with `gitsign`. To this end, there are some configurations that need to be set on the git client:

```bash
git config --local gpg.x509.program gitsign
git config --local gpg.format x509
git config --local commit.gpgsign true
```

After this you will need to set the configurations on your git client for connecting into the elements of the sigstore stack. 

```bash
git config gitsign.rekor <rekor_url>
git config gitsign.fulcio <fulcio_url>
git config gitsign.issuer <issuer_url>
```

You should replace the bracketed components with your values for their URL. Additionally, while the Rekor and Fulcio routes should simply be the basic openshift route for exposing their services, the issuer URL should be the auth realm setup in your OIDC provider (ex: `https://keycloak-keycloak-system.apps.test-cluster.redhat.com/auth/realms/sigstore`).

If everything has been correctly setup, you should be able to sign commits in the usual way (`git commit -m "commit signing message" -S`), which should open up a browser tab where you will authenticate against your OIDC issuer, and then confirm that your commit was signed properly, as well as provide you with a TLOG index for your entry in rekor. As discussed in the introduction, this pipeline was meant to model 2 behaviours; firstly, that all commits are properly signed, and secondly, that all these signatures would be available in the designated rekor log. For this purpose, the `verify-commit-signature-task.yaml` contains a significant amount of code to traverse and process entries in the rekor log, since it is rather difficult to search through it for signed git commits specifically. If one does not wish to do this and simply verify commit signatures, you may comment out most of the code in this task (lines 37, 38, 40-107, and 109-113) to install `gitsign` and run `gitsign verify ...`.

After these `git` configurations have been set, you may also need to set these as environment variables [according to the gitsign documentation](https://docs.sigstore.dev/signing/gitsign/#environment-variables). You will need to set the following values, but refer to the official documentation for more inforation.
1. `SIGSTORE_REKOR_PUBLIC_KEY` with  the URL for which our tuf-mirror served the rekor public key.
2. `GITSIGN_FULCIO_ROOT` with the path to PEM encoded certificate for Fulcio CA (additional alias: SIGSTORE_ROOT_FILE)

Finally, you should verify that `gitsign` recognizes these values and they have been properly set by calling `gitsign --version`. This should spit you out a list of the values set in the `gitsign` configuration, you can use this to help troubleshoot if you are having difficulties configuring gitsign to hook into the other elements of your `trusted-artifact-signer` stack.