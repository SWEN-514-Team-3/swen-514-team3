import uuid

import boto3
import urllib.parse
transcribe = boto3.client('transcribe')

def lambda_handler(event, context):
    print("Yay we made it here!!")