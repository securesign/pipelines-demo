rekor_url="https://$(oc get routes -n rekor-system | grep 'rekor' | awk '{print $2}')/"
issuer_base_url="https://$(oc get routes -n keycloak-system | grep 'keycloak' | head -n 1 | awk '{print $2}')/"
issuer_url="${issuer_base_url}auth/realms/sigstore"
fulcio_url="https://$(oc get routes -n fulcio-system | grep 'fulcio-server-http' | awk '{print $2}')/"
tuf_mirror="https://$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $2}')/"
tuf_root="${tuf_mirror}root.json"

fulcio_crt_pem_url=${tuf_mirror}targets/fulcio-cert
rekor_public_key=${tuf_mirror}targets/rekor.pub
ctfe_public_key=${tuf_mirror}targets/ctfe.pub

echo "apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: trusted-artifact-signer-triggerbinding
spec:
  params:
    - name: fulcio-url
      value: $fulcio_url
    - name: fulcio-crt-pem-url
      value: ${fulcio_crt_pem_url}
    - name: rekor-url
      value: ${rekor_url}
    - name: issuer-url
      value: ${issuer_url}
    - name: tuf-mirror
      value: ${tuf_mirror}
    - name: tuf-root
      value: ${tuf_root}
    - name: rekor-public-key
      value: ${rekor_public_key}
    - name: ctfe-public-key
      value: ${ctfe_public_key}" > ./trusted-artifact-signer-triggerbinding.yaml
