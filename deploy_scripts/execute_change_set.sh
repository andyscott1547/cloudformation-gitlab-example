#!/bin/bash
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

STATUS=(`aws cloudformation describe-change-set --change-set-name "changeset-${CI_COMMIT_SHORT_SHA}" --stack-name ${STACK_NAME} --query Status --output text`)

if [ "${STATUS}" != "FAILED" ]; then
  echo -e "${GREEN}Executing change set changeset-${CI_COMMIT_SHORT_SHA}. Updating ${STACK_NAME}... ${ENDCOLOR}"
  echo -e "-------------------------------------------------------------"
  sleep 10
  aws cloudformation execute-change-set --change-set-name "changeset-${CI_COMMIT_SHORT_SHA}" --stack-name ${STACK_NAME}
else
  echo -e "${RED}Change set in failed state please review changeset ${ENDCOLOR}"
  echo -e "-------------------------------------------------------------"
  exit 1
fi

cloudformation_tail() {
  local lastEvent
  local lastEventId
  local stackStatus=(`aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query Stacks[0].StackStatus --output text`)

  until \
	[ "$stackStatus" = "CREATE_COMPLETE" ] \
	|| [ "$stackStatus" = "CREATE_FAILED" ] \
	|| [ "$stackStatus" = "DELETE_COMPLETE" ] \
	|| [ "$stackStatus" = "DELETE_FAILED" ] \
	|| [ "$stackStatus" = "ROLLBACK_COMPLETE" ] \
	|| [ "$stackStatus" = "ROLLBACK_FAILED" ] \
	|| [ "$stackStatus" = "UPDATE_COMPLETE" ] \
	|| [ "$stackStatus" = "UPDATE_ROLLBACK_COMPLETE" ] \
	|| [ "$stackStatus" = "UPDATE_ROLLBACK_FAILED" ] \
	|| [ -z "$stackStatus" ]; do
	
	eventId=(`aws cloudformation describe-stack-events --stack ${STACK_NAME} --query StackEvents[0].PhysicalResourceId --output text`)
	if [ "$eventId" != "$lastEventId" ]
	then
		echo "Deploying/updating: $eventId"
    lastEventId=$eventId
	fi
	sleep 3
	stackStatus=(`aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query Stacks[0].StackStatus --output text`)
  done

  echo -e "-------------------------------------------------------------"

  if [ "$stackStatus" != "CREATE_COMPLETE" ] && [ "$stackStatus" != "UPDATE_COMPLETE" ] && [ "$stackStatus" != "DELETE_COMPLETE" ] && [ ! -z "$stackStatus" ]; then
    echo -e "${RED}Change Set Failed To Execute.${ENDCOLOR}"
	echo -e "-------------------------------------------------------------"
    exit 1;
  else
    echo -e "${GREEN}Change Set Executed for changeset-${CI_COMMIT_SHORT_SHA}. Updated ${STACK_NAME}. ${ENDCOLOR}"
	echo -e "-------------------------------------------------------------"
  fi
}

cloudformation_tail


