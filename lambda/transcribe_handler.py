import base64
import hashlib
import json
import logging
import os
import re
import uuid

import boto3

LOGGER = logging.getLogger(__name__)
s3 = boto3.client('s3')
transcribe = boto3.client('transcribe')
BUCKET_NAME = os.environ['S3_BUCKET_NAME']


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {'Content-Type': 'application/json', 'Cache-Control': 'no-store'},
        'body': json.dumps(body),
    }


def job_prefix(user_id):
    # Scope jobs to this deployment and Cognito identity, even in a shared account.
    owner = hashlib.sha256(f'{BUCKET_NAME}:{user_id}'.encode()).hexdigest()
    return f'mm-{owner}-'


def lambda_handler(event, context):
    route = event.get('routeKey', '')
    if route not in ('POST /transcribe', 'GET /transcribe/{jobId}'):
        return response(404, {'error': 'Route not found.'})
    claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
    user_id = claims.get('sub')
    if not user_id:
        return response(401, {'error': 'Please sign in before accessing a transcription.'})

    try:
        if route == 'GET /transcribe/{jobId}':
            job_id = (event.get('pathParameters') or {}).get('jobId', '')
            if not re.fullmatch(re.escape(job_prefix(user_id)) + r'[0-9a-f]{32}', job_id):
                return response(404, {'error': 'Transcription not found.'})
            job = transcribe.get_transcription_job(TranscriptionJobName=job_id)['TranscriptionJob']
            status = job['TranscriptionJobStatus']
            if status in ('QUEUED', 'IN_PROGRESS'):
                return response(200, {'status': status.lower(), 'jobId': job_id})
            if status == 'FAILED':
                return response(200, {'status': 'failed', 'jobId': job_id,
                                      'error': 'Transcription failed. Check the recording and try again.'})
            if status != 'COMPLETED':
                raise RuntimeError('Unexpected transcription status')
            key = f'transcripts/{job_id}.json'
            obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
            results = json.loads(obj['Body'].read())['results']
            transcript = results['transcripts'][0]['transcript']
            segments = results.get('audio_segments') or []
            if segments:
                transcript += '\n\nTimestamps:\n' + ''.join(
                    f"{segment['start_time']}-{segment['end_time']}: {segment['transcript']}\n"
                    for segment in segments
                )
            return response(200, {'status': 'completed', 'jobId': job_id,
                                  'service': 'aws-transcribe', 'transcriptPath': key,
                                  'transcript': transcript})

        params = event.get('queryStringParameters') or {}
        use_sample = params.get('sample') == 'true'
        job_id = job_prefix(user_id) + uuid.uuid4().hex
        if use_sample:
            extension = 'm4a'
            key = 'samples/Recording.m4a'
        else:
            filename = (event.get('queryStringParameters') or {}).get('filename', 'audio.m4a')
            extension = filename.rsplit('.', 1)[-1].lower()
            if extension not in ('mp3', 'mp4', 'm4a', 'wav', 'flac', 'ogg', 'amr', 'webm'):
                return response(400, {'error': 'Unsupported media format.'})
            raw_body = event.get('body') or ''
            try:
                audio = base64.b64decode(raw_body, validate=True) if event.get('isBase64Encoded') else (
                    raw_body.encode('utf-8') if isinstance(raw_body, str) else raw_body
                )
            except (ValueError, TypeError):
                return response(400, {'error': 'Invalid audio payload.'})
            if not audio:
                return response(400, {'error': 'No audio file payload received.'})
            key = f'recordings/{job_id}.{extension}'
            s3.put_object(Bucket=BUCKET_NAME, Key=key, Body=audio)
        transcribe.start_transcription_job(
            TranscriptionJobName=job_id,
            Media={'MediaFileUri': f's3://{BUCKET_NAME}/{key}'},
            MediaFormat=extension, LanguageCode='en-US',
            OutputBucketName=BUCKET_NAME, OutputKey=f'transcripts/{job_id}.json',
        )
        return response(202, {'status': 'queued', 'jobId': job_id})
    except Exception:
        LOGGER.exception('Transcription request failed')
        return response(500, {'error': 'Unable to process transcription. Please try again.'})
