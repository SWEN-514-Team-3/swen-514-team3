import base64
import re
import uuid
import json

import boto3
import urllib.parse
import logging

LOGGER = logging.getLogger(__name__)
s3 = boto3.client("s3")
transcribe = boto3.client('transcribe')
BUCKET_NAME = "audio-drop-bucket"

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    print("Yay we made it here!!")
    route = event.get("routeKey", "")

    # print logs because stuff isnt working
    try:
        print(f"[IAM CHECK] Attempting to access S3 bucket '{BUCKET_NAME}'...")
        s3.head_bucket(Bucket=BUCKET_NAME)
        print(f"[IAM CHECK] SUCCESS: Access to S3 bucket '{BUCKET_NAME}' is allowed.")
    except Exception as e:
        print(f"[IAM CHECK] FAILED S3 access: {str(e)}")

    try:
        print("[IAM CHECK] Attempting to access Transcribe service...")
        transcribe = boto3.client("transcribe")
        transcribe.list_transcription_jobs(MaxResults=1)
        print("[IAM CHECK] SUCCESS: 'transcribe:ListTranscriptionJobs' (Transcribe access) allowed.")
    except Exception as e:
        print(f"[IAM CHECK] FAILED Transcribe access: {str(e)}")

    print(f"Incoming route: {route}, http method: {event.get('httpMethod')}")

    if route == "POST /transcribe":
        claims = event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
        if not claims.get("sub"):
            return response(401, {"error": "Please sign in before starting a transcription."})

        # generate uuid
        unique_id = uuid.uuid4().hex[:8]

        # get file name from query params or generate a unique name
        query_params = event.get("queryStringParameters") or {}
        filename = query_params.get("filename", f"audio-{unique_id}.m4a")

        print(f"Target file name for upload: {filename}")

        raw_body = event.get("body", "")
        if event.get("isBase64Encoded"):
            file_bytes = base64.b64decode(raw_body)
        elif isinstance(raw_body, str):
            file_bytes = raw_body.encode("utf-8")
        else:
            file_bytes = raw_body

        if not file_bytes:
            return response(400, {"error": "No audio file payload received."})

        # check if the extension is valid
        file_ext = filename.split(".")[-1].lower() if "." in filename else "m4a"
        if file_ext not in ["mp3", "mp4", "m4a", "wav", "flac", "ogg", "amr", "webm"]:
            return response(400, {"error": f"Unsupported media format: {file_ext}"})

        # upload to s3 bucket
        try:
            s3_key = f"recordings/{unique_id}-{filename}"
            print(f"Uploading file to S3: {s3_key}")

            s3.put_object(Bucket=BUCKET_NAME, Key=s3_key, Body=file_bytes)
            print("Upload successful.")

            # start transcription job
            clean_filename = re.sub(r"[^a-zA-Z0-9-_]", "-", filename)
            job_name = f"transcribe-{clean_filename}-{unique_id}"
            transcribe.start_transcription_job(
                TranscriptionJobName=job_name,
                Media={"MediaFileUri": f"s3://{BUCKET_NAME}/{s3_key}"},
                MediaFormat=file_ext,
                LanguageCode="en-US",
                OutputBucketName=BUCKET_NAME,
                OutputKey=f"transcripts/{job_name}.json"
            )
            print("Transcription job started successfully.")

            return response(200, {
                "status": "completed",
                "service": "aws-transcribe",
                "message": f"Started transcription job {job_name}",
                "jobName": job_name,
                "transcriptPath": f"transcripts/{job_name}.json"
            })
        except Exception as error:
            LOGGER.exception("Transcribe start failed: %s", str(error))
            return response(500, {"error": f"Failed to start transcription: {str(error)}"})

    return response(404, {"error": "Route not found."})