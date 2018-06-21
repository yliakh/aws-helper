#!/bin/bash

usage() {
cat <<EOF
  Usage:
    $0 [options]
  Options:
    -m    STRING  arn of MFA device
    -p    STRING  aws profile name to set temporary credentials for
    -P    STRING  aws profile name to use to get temporary credentials
    [-E]          export temporary credentials as environment variables
    [-r]  STRING  aws default region to use
EOF
exit 1
}

require() {
  command -v $1 > /dev/null 2>&1 || { echo $1 executor not found; exit 1; }
}

require aws
require jq

while getopts "m:p:P:Er:" opt; do
  case $opt in
    m) MFA_ARN=$OPTARG;;
    E) EXPORT=true;;
    p) TMP_PROFILE=$OPTARG;;
    P) PROFILE=$OPTARG;;
    r) AWS_REGION=$OPTARG;;
    :) echo "Option -$OPTARG requires an argument." >&2
       exit 1
       ;;
    \?) usage;;
    *)  usage;;
  esac
done

[[ -z $MFA_ARN ]] && echo "MFA arn is required" && usage

TMP_PROFILE=${TMP_PROFILE-default}
PROFILE=${PROFILE-admin}
AWS_REGION=${AWS_REGION-eu-west-1}

echo Enter MFA token:
read token

creds=$(aws sts get-session-token \
  --serial-number $MFA_ARN \
  --token-code $token \
  --output json \
  --profile $PROFILE
)

if [[ $? -eq 0 ]]; then
  aws configure set region $AWS_REGION

  key=$(echo $creds | jq -c '.Credentials.AccessKeyId' | sed 's/"//g')
  aws configure set aws_access_key_id $key --profile $TMP_PROFILE
  [[ -z $EXPORT ]] || export AWS_ACCESS_KEY_ID=$key

  key=$(echo $creds | jq -c '.Credentials.SecretAccessKey' | sed 's/"//g')
  aws configure set aws_secret_access_key $key --profile $TMP_PROFILE
  [[ -z $EXPORT ]] || export AWS_SECRET_ACCESS_KEY=$key

  key=$(echo $creds | jq -c '.Credentials.SessionToken' | sed 's/"//g')
  aws configure set aws_session_token $key --profile $TMP_PROFILE
  [[ -z $EXPORT ]] || export AWS_SECURITY_TOKEN=$key
fi
