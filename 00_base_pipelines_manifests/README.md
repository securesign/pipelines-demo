# Introduction

This repo contains the `trusted-artifact-signer` pipelines demos. This directory contains the manifests that are pipeline agnostic. These include:

1. The namespace in which we will deploy all these resources.

2. A `Tekton` `TriggerBinding` for recieving data via a Github Webhook

3. A `Tekton` `TriggerBinding` for passing the URLs for the various components of your Sigstore stack to the pipelines

While the namespace and `TriggerBinding` for recieving Github push data are good as is, your values for the `trusted-artifact-signer-triggerbinding.yaml` will not be same as the ones present.

There is a script available in this directory (`./generate-tas-triggerbinding.sh`) that is meant to help you generate this `TriggerBinding` in an automated fashion. It requires that you are logged into an openshift where you have installed your sigstore components, and have standardly named namespaces (`rekor-system`, `ctlog-system`, etc.). For more information on this see our [openshift based charts repo](https://github.com/securesign/sigstore-ocp), or start by using our [easy install script](https://github.com/securesign/sigstore-ocp/blob/main/tas-easy-install.sh). The `generate-tas-triggerbinding.sh` script will overwrite the current `trusted-artifact-signer-triggerbinding.yaml` file, however we have chosen to leave the values for our deployment so you can understand what they are supposed to look like.

Ater generating the `TriggerBinding` using your sigstore routes, build and apply the manifests to your cluster: `oc apply --kustomize ./`

# Summary for Quickstart

```bash
./generate-tas-triggerbinding.sh
oc apply --kustomize ./
```