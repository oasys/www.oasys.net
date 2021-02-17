#!/bin/bash

# initial setup
#  - creates tfc workspace(s)
#  - connects them to the github repo
#  - creates an azure service principal
#  - adds sp credentials to the workspace environment variables

ORG=$(dirname "$(git remote get-url origin)" | cut -d: -f2)
REPO=$(basename -s .git "$(git remote get-url origin)")

# install tf-helper if needed
if ! type "tfh" > /dev/null 2>&1 ; then
  echo "installing tf helper and adding symlink in your ~/bin dir"
  git clone https://github.com/hashicorp-community/tf-helper.git ~/tf-helper
  ln -s ~/tf-helper/tfh/bin/tfh ~/bin/tfh
  tfh curl-config -tfrc # copy token from ~/.terraformrc
fi

# create IAM user and attach required policies
POLICIES=(
  IAMFullAccess
  AmazonS3FullAccess
  CloudFrontFullAccess

)
aws iam create-user --user-name "${REPO}"
for policy in "${POLICIES[@]}"; do
  aws iam attach-user-policy \
    --user-name "${REPO}" \
    --policy-arn "arn:aws:iam::aws:policy/$policy"
done

# delete any existing access-keys
for keyid in $(aws iam list-access-keys --user-name "${REPO}" \
  | jq -r '.[]|.[].AccessKeyId'); do
  aws iam delete-access-key \
    --user-name "${REPO}" \
    --access-key-id "$keyid"
done
IAM_USER=$(aws iam create-access-key --user-name "${REPO}")

# initialize workspace
ws="${REPO}"
export TFH_org=$ORG

# create workspace and add github repo
if ! tfh ws show -name "$ws" >/dev/null 2>&1; then
  echo "creating workspace $ws"
  tfh ws new -name "$ws" -vcs-id "${ORG}/${REPO}"
fi

# set workspace environment variables for authentication to aws
tfh pushvars -name "$ws" \
  -env-var "AWS_ACCESS_KEY_ID=$(echo "$IAM_USER" | \jq -r .AccessKey.AccessKeyId)" \
  -overwrite-env AWS_ACCESS_KEY_ID \
  -senv-var "AWS_SECRET_ACCESS_KEY=$(echo "$IAM_USER" | jq -r .AccessKey.SecretAccessKey)" \
  -overwrite-env AWS_SECRET_ACCESS_KEY \
  -env-var "AWS_DEFAULT_REGION=us-east-1"

# set initial workspace variables
tfh pushvars -name "$ws" \
  -hcl-var "tags={}" \
  -var "deploy_arn=$(aws iam get-user --user-name "${REPO}" | jq -r '.User.Arn')" \
  -overwrite deploy_arn
