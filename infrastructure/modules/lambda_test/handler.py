import json


def lambda_handler(event, context):
    print("Private-network Lambda invocation succeeded")
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Private-network Lambda invocation succeeded"}),
    }
