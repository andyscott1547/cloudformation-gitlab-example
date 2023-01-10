#!/bin/bash
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

echo -e "-------------------------------------------------------------"
aws cloudformation describe-stacks --stack-name ${STACK_NAME}
aws cloudformation list-stack-resources --stack-name ${STACK_NAME}

echo -e "-------------------------------------------------------------"
echo -e "${GREEN}Testing complete for ${CI_COMMIT_SHORT_SHA} on ${CI_COMMIT_BRANCH}. Deleting ${STACK_NAME}... ${ENDCOLOR}"
echo -e "-------------------------------------------------------------"

aws cloudformation delete-stack --stack-name ${STACK_NAME}

echo -e "${GREEN}Deleted ${STACK_NAME}.${ENDCOLOR}"
echo -e "-------------------------------------------------------------"
