oc get serviceaccount pipeline -n $(oc project -q) -o yaml > ./test
# oc 