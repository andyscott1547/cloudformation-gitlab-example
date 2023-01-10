#! /bin/bash -e

temp_role=$(aws sts assume-role \
            --role-arn "arn:aws:iam::533306432062:role/NetworkAutomationRole" \
            --role-session-name "network_role")
 
export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)

env | grep -i AWS_ 