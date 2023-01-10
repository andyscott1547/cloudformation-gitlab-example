#!/bin/bash
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

TEST_STACK=(`aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION} --output text || true`)
CHANGE_TYPE="UPDATE"

if [ -z "${TEST_STACK}" ]; then
  CHANGE_TYPE="CREATE"
fi

aws cloudformation create-change-set --stack-name ${STACK_NAME} --template-body file://${TEMPLATE_NAME} --change-set-name "changeset-${CI_COMMIT_SHORT_SHA}" --change-set-type ${CHANGE_TYPE} --parameters file://${CI_ENVIRONMENT_NAME}.json --capabilities CAPABILITY_IAM
STATUS=(`aws cloudformation describe-change-set --change-set-name "changeset-${CI_COMMIT_SHORT_SHA}" --stack-name ${STACK_NAME} --query Status --output text`)

until [ "$STATUS" = "CREATE_COMPLETE" ] || [ "$STATUS" = "FAILED" ]; do
  echo "Generating Change Set For ${STACK_NAME}..."
  STATUS=(`aws cloudformation describe-change-set --change-set-name "changeset-${CI_COMMIT_SHORT_SHA}" --stack-name ${STACK_NAME} --query Status --output text`)
  sleep 3
done

echo -e "-------------------------------------------------------------"

if [ "$STATUS" == "FAILED" ]; then
  echo -e "${RED}Create change set FAILED ${ENDCOLOR}"
  STATUS_REASON=$(aws cloudformation describe-change-set --change-set-name "changeset-${CI_COMMIT_SHORT_SHA}" --stack-name ${STACK_NAME} --query StatusReason --output text)
  echo ${STATUS_REASON}
  if [ "$STATUS_REASON" == "The submitted information didn't contain changes. Submit different information to create a change set." ]; then
    echo -e "${RED}Create change set FAILED no changes to be made to the stack. ${ENDCOLOR}"
    echo -e "-------------------------------------------------------------"
  else
    echo -e "${RED}Create change set FAILED issue with template or resources to be deployed. ${ENDCOLOR}"
    echo -e "-------------------------------------------------------------"
  fi
  exit 1
else
  echo -e "${GREEN}Change Set successfully generated. ${ENDCOLOR}"
  echo -e "-------------------------------------------------------------"
fi


