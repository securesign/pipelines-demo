# Tekton Chains + keyless signing with AWS STS

More thorough documentation written [here](https://github.com/securesign/sigstore-ocp/blob/6f619d3b3524978de47833d10a4ea334bc1fb6d0/docs/sts/aws-sts.md) by Sally O'Malley. Thanks to her for paving the way for this work and @sabre1041 for working on this demo with me.

## Setup

### Demo pre-reqs

This demo requires:
1. Access to A ROSA cluster with STS enabled
2. The corresponding AWS account with permissions to create a new IAM role
3. A properly configured AWS IAM Identity Provider (you should already have this in setting up the ROSA STS cluster)
4. An installation of RHTAS (doesn't have to be on the ROSA STS cluster but can be)
5. An installation of Openshift Pipelines
    - It is possible to do this with just tekton chains but this demo was built Openshift Pipelines in mind
6. A git repo for a containerized application (in this demo we use https://github.com/Gregory-Pereira/pacman.git)
7. A Quay.io account and repository with a robot account that has write permissions on that repository (in this demo we use `securesign_demo`)
8. A namespace in which to apply the demo manifests (in this demo we use `cosign`)

### Gather your variables

You should gather some pieces of information that will be used in the demo:

1. OIDC issuer:
    - this can be acquired by: `oc get authentication cluster -o jsonpath='{.spec.serviceAccountIssuer}'` in your ROSA STS cluster
    - this value will be referred to as `<OIDC_ISSUER>` throughout this demo
2. AWS account ID
    - this is the 12 digit ID number that you use to sign into AWS
    - this value will be referred to as `<AWS_ACCOUNT_ID>` throughout this demo
3. OIDC client ID: 
    - you can set this to be whatever you want but for this demo we use `sigstore`. Just make sure whatever you change is consistent with the other places you'd have to set this (`Securesign` CR, [sts-sa](./test-signing-without-pipeline/sts-sa.yaml#L9), [cosign deployment](./test-signing-without-pipeline/sts-cos-deployment.yaml#L37), and anywhere else you set this). Create your role for the `arn`: `arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE_NAME>` for your respective OIDC issuer.
    - this value will be referred to as `<OIDC_CLIENT_ID>` throughout this demo

## Steps


### Setup AWS Role

Using the variables you gathered above fill out the [role template](./aws/sts-role-tmpl.json). Optionally you can also swap out the `<OIDC_CLIENT_ID>` from `sigstore` to be whatever you wish as your OIDC Client ID. For any of our friends using the ET AWS account for this demo, we name this role `rhtas-sts`.

### Create the service account that will run the pipeline

#### Give the SA the robot pull-secret to push images to the Quay repo

First, ensure that you have created a repo for your applicaiton in your quay account. After you have created the repo, create a robot account and give it write access on the quay repo you just created. Then, download the robot account creds and create them as a secret.

`oc create secret -f ~/Downloads/grpereir-securesign-demo-secret.yml -n cosign`

After this, update the [`rhtas-sa.yaml`](./rhtas-sa.yaml#L7) to reference secret that you uploaded.

Finally, you can create the sa: `oc create -f rhtas-sa.yaml`

#### give the pipeline image building SA correct SCC

You could just make the pipeline run with the `pipeline` serviceAccount that ships with openshift-pipelines but were demoing 0 trust here, so we will instead create our own SA and apply the SCC to it, showing how you can only let through what actions you want.

To add the pipelines-scc to our `rhtas-sa` service account in the `cosign` namepace we are using, we would do the following: `oc adm policy add-scc-to-user pipelines-scc -z rhtas-sa -n cosign`

### edit the securesign

We have to edit to enable STS OIDC issuer. If you have one securesign instance in cluster we can use the following script to find its name and namespace and edit it:

```
securesign_ns=$(oc get securesign -A | tail -n 1 | awk '{print $1}')
securesign_name=$(oc get securesign -A | tail -n 1 | awk '{print $2}')
oc edit securesign $securesign_name -n $securesign_ns
```

Our goal in editing this is to enable a new OIDC issuer, so add an entry `spec.fulcio.config.OIDCIssuers` array that resembles the following, using the `<OIDC_ISSUER` we found above>:
```
- ClientID: sigstore
  Issuer: <OIDC_ISSUER>
  IssuerURL: <OIDC_ISSUER>
  Type: kubernetes
```

### Apply the Tekton manifests

First thing we will configure is the [tektonConfig](./tekton/tektonConfig.yaml). Make sure to swap in your RHTAS routes for Fulcio, TUF, Rekor, and your OIDC issuer. After this you can apply the `tektonConfig`: `oc apply -f ./tekton/tektonConfig.yaml`. 

Next were going to create the tekton pipeline. If you are using a different `git` repo make sure to adjust the [`DOCKERFILE` variable](./tekton/pipeline.yaml#L39) accordingly. Aside from that, you can apply the pipeline out of the box: `oc apply -f ./tekton/pipeline.yaml`

Finally we need to configure our pipelineRun. Pass in the `git` repo and Quay repo you wish to use for this demo, and then we can kickoff the pipeline: `oc create -f ./tekton/pipelinerun.yaml`

## test-signing-without-pipeline

Whats this [`test-signing-without-pipeline`](./test-signing-without-pipeline/) directory? The first step in setting up this demo was just to test the signing with STS piece, and so I thought to include these manifests along with the demo. Feel free to use these manifests to test the signing in an easier way

Just make sure to login to `registry.redhat.io` and pull the cosign image. After that is done, we can import it to the cluster: 
```
podman login registry.redhat.io
# enter creds and login
podman pull registry.redhat.io/rhtas/cosign-rhel9:1.0.1-1716203248
oc import-image rhtas/cosign-rhel9:1.0.1-1716203248 --from=registry.redhat.io/rhtas/cosign-rhel9:1.0.1-1716203248 --confirm
```

After that you can just deploy the sa and deployment and then run the signing test. Just make sure to apply your `AWS_ACCOUNT_ID` and `ROLE_NAME` to the sa first.

```
# MAKE SURE TO EDIT THE SA AND DEPLOYMENT WITH YOUR VALUES
oc apply -f ./test-signing-without-pipeline/sts-sa.yaml
oc apply -f ./test-signing-without-pipeline/sts-cos-deployment.yaml
sleep 20 # give openshift enough time to create the SA and deployment
./signing-test.sh
```