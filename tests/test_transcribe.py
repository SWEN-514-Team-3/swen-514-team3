import base64
import io
import json
import os
import runpy
import types
import unittest
from unittest.mock import Mock, patch


class TranscribeTests(unittest.TestCase):
    def setUp(self):
        self.s3, self.transcribe = Mock(), Mock()
        sdk = types.SimpleNamespace(client=lambda name: self.s3 if name == 's3' else self.transcribe)
        with patch.dict('sys.modules', {'boto3': sdk}), patch.dict(os.environ, {'S3_BUCKET_NAME': 'unique-recordings-test'}):
            self.module = runpy.run_path('lambda/transcribe_handler.py')
        self.job = self.module['job_prefix']('alice') + 'a' * 32

    def call(self, route='GET /transcribe/{jobId}', user='alice', **extra):
        event = {'routeKey': route, 'pathParameters': {'jobId': self.job},
                 'requestContext': {'authorizer': {'jwt': {'claims': {'sub': user}}}}}
        event.update(extra)
        result = self.module['lambda_handler'](event, None)
        return result['statusCode'], json.loads(result['body'])

    def test_start_returns_without_polling(self):
        status, body = self.call('POST /transcribe', body=base64.b64encode(b'audio').decode(),
                                 isBase64Encoded=True, queryStringParameters={'filename': 'test.wav'})
        self.assertEqual(status, 202)
        self.assertEqual(body['status'], 'queued')
        self.transcribe.get_transcription_job.assert_not_called()
        self.assertEqual(self.s3.put_object.call_args.kwargs['Bucket'], 'unique-recordings-test')
        self.assertEqual(self.transcribe.start_transcription_job.call_args.kwargs['OutputBucketName'], 'unique-recordings-test')

    def test_other_user_is_denied_before_aws_call(self):
        self.assertEqual(self.call(user='bob')[0], 404)
        self.transcribe.get_transcription_job.assert_not_called()

    def test_unauthenticated(self):
        self.assertEqual(self.call(user=None)[0], 401)

    def test_running_and_failed_status(self):
        for aws_status, expected in [('QUEUED', 'queued'), ('IN_PROGRESS', 'in_progress'), ('FAILED', 'failed')]:
            self.transcribe.get_transcription_job.return_value = {'TranscriptionJob': {'TranscriptionJobStatus': aws_status}}
            self.assertEqual(self.call()[1]['status'], expected)
        self.s3.get_object.assert_not_called()

    def test_completed_without_optional_segments(self):
        self.transcribe.get_transcription_job.return_value = {'TranscriptionJob': {'TranscriptionJobStatus': 'COMPLETED'}}
        self.s3.get_object.return_value = {'Body': io.BytesIO(json.dumps({'results': {'transcripts': [{'transcript': 'Hello'}]}}).encode())}
        self.assertEqual(self.call()[1]['transcript'], 'Hello')

    def test_invalid_audio_is_rejected(self):
        self.assertEqual(self.call('POST /transcribe', body='%%%!', isBase64Encoded=True)[0], 400)
        self.assertEqual(self.call('POST /transcribe', body='')[0], 400)
        self.s3.put_object.assert_not_called()

if __name__ == '__main__':
    unittest.main()
