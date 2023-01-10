import os
import json
import boto3
import logging

ec2 = boto3.client("ec2")

logger = logging.getLogger(__name__)
log_level = os.environ.get('LOGGING_LEVEL', logging.INFO)
logger.setLevel(log_level)


def create_name_tag(attach_id, vpc_attach_name):
    try:
        ec2.create_tags(
            Resources=[
                attach_id,
            ],
            Tags=[
                {
                    'Key': 'Name',
                    'Value': vpc_attach_name
                },
            ]
        )
        logger.info(f"Added name tag of {vpc_attach_name} to TGW attachment {attach_id}")
    except Exception as e:
        logger.error(e)
        raise


def delete_name_tag(attach_id, vpc_attach_name):
    try:
        ec2.delete_tags(
            Resources=[
                attach_id,
            ],
            Tags=[
                {
                    'Key': 'Name',
                    'Value': vpc_attach_name
                },
            ]
        )
        logger.info(f"Removed name tag of {vpc_attach_name} from TGW attachment {attach_id}")
    except Exception as e:
        logger.error(e)
        raise


def lambda_handler(event, context):
    # logger.info(f"The incoming event was: {event}")
    body = json.loads(event['Records'][0]['body'])
    vpcinfo = json.loads(body['Message'])
    logger.info(f"VPC info was: {vpcinfo}")

    eventType = vpcinfo.get("EventType")
    attach_id = vpcinfo.get("VpcAttachId")
    account_id = vpcinfo.get("AccountId")
    vpc_id = vpcinfo.get("VpcId")
    vpc_name = vpcinfo.get("VpcName")
    vpc_attach_name = f"{vpc_name}-{account_id}"

    if eventType.upper() in ["CREATE", "UPDATE"]:
        logger.info(f"Creating name tag for TGW attachment of {vpc_id}, "
                    f"which belongs to account {account_id}")
        create_name_tag(attach_id, vpc_attach_name)
    elif eventType.upper() in ["DELETE"]:
        logger.info(f"Removing name tag for TGW attachment of {vpc_id}, "
                    f"which belongs to account {account_id}")
        delete_name_tag(attach_id, vpc_attach_name)
    else:
        logger.error(f"Unknown CFN event type: {eventType.upper()}")
