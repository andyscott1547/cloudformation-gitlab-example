#!/bin/bash
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

TEST_STACK=(`aws cloudformation describe-stack-set --stack-set-name ${STACK_NAME} --output text --call-as DELEGATED_ADMIN || true`)
CHANGE_TYPE="UPDATE"

cloudformation_stackset_tail() {
  local lastEvent
  local lastEventId
  local stackSetStatus=(`aws cloudformation list-stack-set-operations --stack-set-name ${STACK_NAME} --query Summaries[0].Status --output text --call-as DELEGATED_ADMIN`)

  until [ "$stackSetStatus" = "SUCCEEDED" ]; do
    echo "StackSet updating for ${STACK_NAME}"
    stackSetStatus=(`aws cloudformation list-stack-set-operations --stack-set-name ${STACK_NAME} --query Summaries[0].Status --output text --call-as DELEGATED_ADMIN`)
    sleep 3
  done

  echo -e "${GREEN}$CHANGE_TYPE complete on ${STACK_NAME}. ${ENDCOLOR}"
  sleep 5
  echo -e "-------------------------------------------------------------"
}

cloudformation_stackset_create_tail() {
  local lastEvent
  local lastEventId
  local stackSetStatus=(`aws cloudformation describe-stack-set --stack-set-name ${STACK_NAME} --query StackSet.Status --output text --call-as DELEGATED_ADMIN`)

  until [ "$stackSetStatus" = "ACTIVE" ]; do
    echo "StackSet updating for ${STACK_NAME}"
    stackSetStatus=(`aws cloudformation describe-stack-set --stack-set-name ${STACK_NAME} --query StackSet.Status --output text --call-as DELEGATED_ADMIN`)
    sleep 3
  done

  echo -e "${GREEN}$CHANGE_TYPE complete on ${STACK_NAME}. ${ENDCOLOR}"
  sleep 5
  echo -e "-------------------------------------------------------------"
}

cloudformation_stackset_instances_tail() {
  INSTANCE_ID=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --query Summaries[*].Account --output text --call-as DELEGATED_ADMIN)

  for INSTANCE in $INSTANCE_ID; do
    INSTANCE_STATUS=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --stack-instance-account ${INSTANCE} --stack-instance-region ${REGION} --query Summaries[*].StackInstanceStatus.DetailedStatus --output text --call-as DELEGATED_ADMIN)
    while [ "$INSTANCE_STATUS" = "RUNNING" ] || [ "$INSTANCE_STATUS" = "PENDING" ]; do
      echo "StackSet updating for account ${INSTANCE} status ${INSTANCE_STATUS}"
      INSTANCE_STATUS=$(aws cloudformation list-stack-instances --stack-set-name ${STACK_NAME} --stack-instance-account ${INSTANCE} --stack-instance-region ${REGION} --query Summaries[*].StackInstanceStatus.DetailedStatus --output text --call-as DELEGATED_ADMIN)
      sleep 1
    done
    echo "Checking deployment status of ${INSTANCE} account..."
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

  echo -e "-------------------------------------------------------------"
      
  if [ ${#FAILURES[@]} -eq 0 ]; then
    echo -e "${GREEN}All Stackset instances created SUCCESSFULLY. ${ENDCOLOR}"
    echo -e "-------------------------------------------------------------"
  else
    echo -e "${RED}Create stack set instance FAILED for ${FAILURES} accounts. ${ENDCOLOR}"
    echo -e "-------------------------------------------------------------"
    exit 1
  fi
}

if [ -z "${TEST_STACK}" ]; then
  CHANGE_TYPE="CREATE"
fi

if [ $CHANGE_TYPE == "CREATE" ]; then
  aws cloudformation create-stack-set --stack-set-name ${STACK_NAME} --template-body file://${TEMPLATE_NAME} --parameters file://${CI_ENVIRONMENT_NAME}.json --permission-model SERVICE_MANAGED --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=true --call-as DELEGATED_ADMIN --capabilities CAPABILITY_NAMED_IAM
  sleep 5
  echo -e "${GREEN}Stack Set Creating... ${ENDCOLOR}"
  echo -e "-------------------------------------------------------------"
  cloudformation_stackset_create_tail
  sleep 10
elif [ $CHANGE_TYPE == "UPDATE" ]; then
  aws cloudformation update-stack-set --stack-set-name ${STACK_NAME} --template-body file://${TEMPLATE_NAME} --parameters file://${CI_ENVIRONMENT_NAME}.json --permission-model SERVICE_MANAGED --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=true --call-as DELEGATED_ADMIN --capabilities CAPABILITY_NAMED_IAM
  cloudformation_stackset_tail
  cloudformation_stackset_instances_tail
  echo -e "${GREEN}Stack Set Updating... ${ENDCOLOR}"
  echo -e "-------------------------------------------------------------"
else
  echo -e "${RED}Create Stack Set FAILED. ${ENDCOLOR}"
fi

#IS_ACTIVE=$(aws cloudformation list-stack-sets --query 'Summaries[?(StackSetName==`'"$STACK_NAME"'` && IS_ACTIVE==`ACTIVE`)]' --output text)
#aws cloudformation list-stack-sets --query 'Summaries[?(StackSetName==`'"$STACK_NAME"'` && IS_ACTIVE==`ACTIVE`)]' --output text
#echo $IS_ACTIVE
# aws cloudformation list-stack-set-operations --stack-set-name ${STACK_NAME} --query Summaries[0].Status






