#!/bin/bash
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

cloudformation_stackset_instances_tail() {
  INSTANCE_ID=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --query Summaries[*].Account --output text --call-as DELEGATED_ADMIN)

  for INSTANCE in $INSTANCE_ID; do
    INSTANCE_STATUS=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --stack-instance-account ${INSTANCE} --stack-instance-region ${REGION} --query Summaries[*].StackInstanceStatus.DetailedStatus --output text --call-as DELEGATED_ADMIN)
    while [ "$INSTANCE_STATUS" = "RUNNING" ] || [ "$INSTANCE_STATUS" = "PENDING" ]; do
      echo "StackSet updating for account ${INSTANCE} status ${INSTANCE_STATUS}..."
      INSTANCE_STATUS=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --stack-instance-account ${INSTANCE} --stack-instance-region ${REGION} --query Summaries[*].StackInstanceStatus.DetailedStatus --output text --call-as DELEGATED_ADMIN)
      sleep 1
    done
    echo -e "-------------------------------------------------------------"
    echo "Stackset updated for account ${INSTANCE}."
  done

  echo -e "-------------------------------------------------------------"

  FAILURES=()

  for INSTANCE in $INSTANCE_ID; do
    INSTANCE_STATUS=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --stack-instance-account ${INSTANCE} --stack-instance-region ${REGION} --query Summaries[*].StackInstanceStatus.DetailedStatus --output text --call-as DELEGATED_ADMIN)
    if [ "$INSTANCE_STATUS" = "FAILED" ] || [ "$INSTANCE_STATUS" = "CANCELLED" ] || [ "$INSTANCE_STATUS" = "INOPERABLE" ]; then
      echo -e "${RED}Create stack set FAILED for ${INSTANCE} account. ${ENDCOLOR}"
      FAILURES[${#FAILURES[@]}]=${INSTANCE}
    elif [ "$INSTANCE_STATUS" = "SUCCEEDED" ]; then
      echo -e "${GREEN}Create stack set instances SUCCEEDED for ${INSTANCE} account. ${ENDCOLOR}"
    else
      echo -e "${RED}Unexpected error occured for ${INSTANCE} account. ${ENDCOLOR}"
    fi
  done

  echo -e "--------------------------------------------------------------"
      
  if [ ${#FAILURES[@]} -eq 0 ]; then
    echo -e "${GREEN}All Stackset instances created SUCCESSFULLY. ${ENDCOLOR}"
  else
    echo -e "${RED}Create stack set instance FAILED for ${FAILURES} accounts. ${ENDCOLOR}"
    exit 1
  fi

  echo -e "-------------------------------------------------------------"
}

TEST_STACK=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --query Summaries --output text --call-as DELEGATED_ADMIN)

if [ -z "${TEST_STACK}" ]; then
  aws cloudformation create-stack-instances --stack-set-name ${STACK_NAME} --deployment-targets OrganizationalUnitIds=${OU} --regions ${REGION} --call-as DELEGATED_ADMIN
  sleep 20
  cloudformation_stackset_instances_tail
else
  echo -e "${GREEN}Stack instances already created for ${STACK_NAME} deployed to ${OU}. ${ENDCOLOR}"
  echo -e "-------------------------------------------------------------"
fi



