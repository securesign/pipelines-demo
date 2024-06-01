POD_NAME=$(oc get pods -n cosign -l app=cosign-sts -o jsonpath='{ .items[0].metadata.name }')
if [[ -z $POD_NAME ]]; then
    echo "Pod name for the cosign signer has not been found"
    exit 1
fi
echo "FROM scratch" > Containerfile
podman build . -f Containerfile -t ttl.sh/rhtas/cosign-test:1h
podman push ttl.sh/rhtas/cosign-test:1h
oc exec -n cosign ${POD_NAME} -- /bin/sh -c 'cosign sign -y --identity-token=$AWS_WEB_IDENTITY_TOKEN_FILE ttl.sh/rhtas/cosign-test:1h'
