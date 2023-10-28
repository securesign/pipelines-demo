# Tell git to use gitsign as the signing binary and what to sign through git configurations

echo "This script sets some git configurations for signing commits with the trusted-artifact-signer stack. 
If this is a personal device or development environment it is recommended you set these locally, but if this environment is ephemeral they should be set globally."
read -p "Would you like to set these globally (G/g) or locally (L/l)?: " -n1 config_scope
echo ""

if [[ $config_scope == "G" || $config_scope == "g" ]]; then
    git config --global gpg.x509.program gitsign
    git config --global gpg.format x509
    git config --global commit.gpgsign true
elif [[ $config_scope == "L" || $config_scope == "l" ]]; then
    echo "Set these git configs in the local copy of the git repo with the webhook:
        git config --local gpg.x509.program gitsign
        git config --local gpg.format x509
        git config --local commit.gpgsign true
    " 
else
    echo "Please try again with valid input."
    exit 0
fi

# Hook gitsign into your sigstore stack through git configurations

rekor_url=$(oc get routes -n rekor-system | grep 'rekor' | awk '{print $2}')/
issuer_base_url=$(oc get routes -n keycloak-system | grep 'keycloak' | head -n 1 | awk '{print $2}')
issuer_url=${issuer_base_url}/auth/realms/sigstore
fulcio_url=$(oc get routes -n fulcio-system | grep 'fulcio-server-http' | awk '{print $2}')/
tuf_mirror=$(oc get routes -n tuf-system | grep 'tuf' | awk '{print $2}')
rekor_public_key=${tuf_mirror}/targets/rekor-pubkey
fulcio_root=${tuf_mirror}/targets/fulcio-cert

git config --global gitsign.rekor ${rekor_url}
git config --global gitsign.fulcio ${fulcio_url}
git config --global gitsign.issuer ${issuer_url}

# set git identifiers

git_name=$(git config --get user.name)
git_email=$(git config --get user.email)

if [[ -z $git_name ]]; then 
    read -p "Please enter your name for your git config: " git_users_name
    echo ""
    git config --global user.name $git_users_name
fi

if [[ -z $git_email ]]; then
    read -p "Please enter your your email for your git config: " git_users_email
    echo ""
    git config --global user.email $git_users_email
fi

# set the env variables

export GITSIGN_FULCIO_URL=https://${fulcio_url}
export GITSIGN_OIDC_CLIENT_ID="sigstore"
export GITSIGN_OIDC_ISSUER=https://${issuer_url}
export GITSIGN_REKOR_URL=https://${rekor_url}
export GITSIGN_REKOR_PUBLIC_KEY=https://${rekor_public_key}
export GITSIGN_FULCIO_ROOT=https://${fulcio_root}

