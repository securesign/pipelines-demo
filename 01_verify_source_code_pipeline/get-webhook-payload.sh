tuf_route_name=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $1}')
tuf_route_hostname=$(oc get route -n tuf-system $tuf_route_name -o jsonpath='{.spec.host}')
generic_route_hostname="${tuf_route_hostname:4:${#tuf_route_hostname}}/"
export GITHUB_WEBHOOK_PAYLOAD_URL="https://el-verify-source.$generic_route_hostname"
echo "GITHUB_WEBHOOK_PAYLOAD_URL=$GITHUB_WEBHOOK_PAYLOAD_URL"