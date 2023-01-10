import os
import json
import boto3
import logging

ec2 = boto3.client("ec2")

logger = logging.getLogger(__name__)
log_level = os.environ.get('LOGGING_LEVEL', logging.INFO)
logger.setLevel(log_level)


def manage_tgw_association(eventType, attach_id, route_table):
    try:
        if eventType.upper() == "CREATE":
            response = ec2.associate_transit_gateway_route_table(
                TransitGatewayRouteTableId=route_table,
                TransitGatewayAttachmentId=attach_id
            )
            logger.info(f"Association of {route_table} and {attach_id} "
                        f"got a response of: {response}")
        elif eventType.upper() == "UPDATE":
            # add logic to check if already associated
            # if not associated, do the association
            # OR could remove then recreate the association
            pass
        elif eventType.upper() == "DELETE":
            response = ec2.disassociate_transit_gateway_route_table(
                TransitGatewayRouteTableId=route_table,
                TransitGatewayAttachmentId=attach_id
            )
            logger.info(f"Disassociation of {route_table} and {attach_id} "
                        f"got a response of: {response}")
        else:
            raise ValueError(f"Unknown event type: {eventType.upper()}")
    except Exception as e:
        logger.error(e)
        raise


def manage_tgw_propagations(eventType, attach_id, route_table):
    try:
        if eventType.upper() == "CREATE":
            for rt in [route_table, os.environ["SHARED_ROUTE_TABLE"]]:
                response = ec2.enable_transit_gateway_route_table_propagation(
                    TransitGatewayRouteTableId=rt,
                    TransitGatewayAttachmentId=attach_id
                )
                logger.info(f"Propagating CIDR of {attach_id} to {rt} "
                            f"got a response of: {response}")
        elif eventType.upper() == "UPDATE":
            # add logic to check if already propagating
            # if not propagating, do the propagation
            # OR could remove then recreate the propagation
            pass
        elif eventType.upper() == "DELETE":
            for rt in [route_table, os.environ["SHARED_ROUTE_TABLE"]]:
                response = ec2.disable_transit_gateway_route_table_propagation(
                    TransitGatewayRouteTableId=rt,
                    TransitGatewayAttachmentId=attach_id
                )
                logger.info(f"Disabling propagation of the {attach_id} CIDR to {rt} "
                            f"got a response of: {response}")
        else:
            raise ValueError(f"Unknown event type: {eventType.upper()}")
        return response
    except Exception as e:
        logger.error(e)
        raise


def lambda_handler(event, context):
    # logger.info(f"The incoming event was: {event}")
    body = json.loads(event['Records'][0]['body'])
    vpcinfo = json.loads(body['Message'])

    eventType = vpcinfo.get("EventType")
    attach_id = vpcinfo.get("VpcAttachId")
    env = vpcinfo.get("Env")

    if env.upper() in ['DEV', 'TEST', 'SANDBOX', 'CI']:
        route_table = os.environ["NONPROD_ROUTE_TABLE"]
    elif env.upper() in ['PROD']:
        route_table = os.environ["PROD_ROUTE_TABLE"]
    elif env.upper() in ['MGMT', 'HZ-SVC']:
        route_table = os.environ["SHARED_ROUTE_TABLE"]
    else:
        raise ValueError(f"Unrecognized value for env: {env}")

    manage_tgw_association(eventType, attach_id, route_table)
    manage_tgw_propagations(eventType, attach_id, route_table)
