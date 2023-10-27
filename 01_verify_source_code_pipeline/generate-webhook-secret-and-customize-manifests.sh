webhook_secret_exists=$(oc get secret webhook-secret-verify-source-code-pipeline-demo -n securesign-pipelines-demo --ignore-not-found)
if [[ -n $webhook_secret_exists ]]; then
  echo "Already found an existing \"webhook-secret-verify-source-code-pipeline-demo\" Secret in the \"securesign-pipelines-demo\" namespace."
  read -s -p "Enter what you would like to update this secret to (leave blank to not change it): " webhook_secret
  echo ""
  if [[ -n $webhook_secret ]]; then
    oc create secret generic webhook-secret-verify-source-code-pipeline-demo -n securesign-pipelines-demo \
      --from-literal=webhook-secret-key=$webhook_secret  --dry-run=client -o yaml | oc replace -f -
  fi
else
  read -s -p "Enter the secret value used to setup the Github webhook: " webhook_secret
  oc create secret generic webhook-secret-verify-source-code-pipeline-demo --from-literal=webhook-secret-key=$webhook_secret -n securesign-pipelines-demo
  echo ""
fi

read -p "Enter the case sensitive github organization and repo combination (ex: 'securesign/pipelines-demo'): " github_org_and_repo

echo "apiVersion: triggers.tekton.dev/v1alpha1
kind: EventListener
metadata:
  name: verify-source
  namespace: securesign-pipelines-demo
spec:
  resources:
    kubernetesResource:
      replicas: 1
  serviceAccountName: pipeline
  triggers: 
    - bindings:
        - kind: TriggerBinding
          ref: github-push-triggerbinding
        - kind: TriggerBinding
          ref: trusted-artifact-signer-triggerbinding
        - kind: TriggerBinding
          ref: verify-source-code-triggerbinding
      interceptors:
        - params:
            - name: secretRef
              value:
                secretKey: webhook-secret-key
                secretName: webhook-secret-verify-source-code-pipeline-demo
          ref:
            kind: ClusterInterceptor
            name: github
        - params:
            - name: filter 
              value: >-
                (header.match('X-GitHub-Event', 'push') &&
                body.repository.full_name == '$github_org_and_repo')
            - name: overlays
              value:
                - expression: 'body.ref.split(''/'')[2]'
                  key: ref
          ref:
            kind: ClusterInterceptor
            name: cel
      name: verify-source-code-trigger
      template: 
        ref: verify-source-code-triggertemplate
" > ./verify-source-el.yaml

server_api_url=$(oc whoami --show-server)
host_plus_port="el-verify-source.apps.${server_api_url:12:${#server_api_url}}"
host_plus_port_length=${#host_plus_port}
host="${host_plus_port:0:$((host_plus_port_length - 5))}"

echo "apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: el-verify-source
  namespace: securesign-pipelines-demo
spec:
  host: $host
  port:
    targetPort: http-listener
  to:
    kind: Service
    name: el-verify-source
    weight: 100
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None" > ./verify-source-el-route.yaml

echo "------------------ Keycloak User Configuration -----------------"
read -p "Enter the username for the keycloak user (must be all lowercase letters): " keycloak_user
keycloak_user=$(echo "$keycloak_user" | awk '{print tolower($0)}')
read -s -p "Now enter the password for the keycloak user: " keycloak_pass
echo ""
read -p "Please enter an email for the keycloak user: " keycloak_email
read -p "Enter your first name: " first_name
read -p "Enter your last name: " last_name

echo "apiVersion: keycloak.org/v1alpha1
kind: KeycloakUser
metadata:
  labels:
    app: sso
  name: $keycloak_user
  namespace: keycloak-system
spec:
  realmSelector:
    matchLabels:
      app: sso
  user:
    email: $keycloak_email
    enabled: true
    emailVerified: true
    credentials:
      - type: "password"
        value: $keycloak_pass
    firstName: $first_name
    lastName: $last_name
    username: $keycloak_user" > ./keycloak-user.yaml

echo "apiVersion: triggers.tekton.dev/v1alpha1
kind: TriggerBinding
metadata:
  name: verify-source-code-triggerbinding
  namespace: securesign-pipelines-demo
spec:
  params:
    - name: oidc-user-email
      value: $keycloak_email
" > ./verify-source-code-triggerbinding.yaml
