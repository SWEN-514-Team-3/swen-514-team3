import uuid

import boto3
import urllib.parse
transcribe = boto3.client('transcribe')

def lambda_handler(event, context):
    print("Yay we made it here!!")
    try:
        headers = event['headers']
        body = event['body']
        return {
            'statusCode': 200,
            'headers': headers,
            'body': body
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }