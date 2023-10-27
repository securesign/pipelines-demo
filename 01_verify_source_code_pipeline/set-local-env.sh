

# Tell git to use gitsign as the signing binary and what to sign through git configurations

git config --local gpg.x509.program gitsign
git config --local gpg.format x509
git config --local commit.gpgsign true

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


read -p "Please enter your name for your git config" git_users_name
read -p "Please enter your your email for your git config" git_users_email

git config --global user.name $git_users_name
git config --global user.email $git_users_email

# set the env variables

export GITSIGN_FULCIO_URL=https://${fulcio_url}
export GITSIGN_OIDC_CLIENT_ID="sigstore"
export GITSIGN_OIDC_ISSUER=https://${issuer_url}
export GITSIGN_REKOR_URL=https://${rekor_url}
export GITSIGN_REKOR_PUBLIC_KEY=https://${rekor_public_key}
export GITSIGN_FULCIO_ROOT=https://${fulcio_root}

