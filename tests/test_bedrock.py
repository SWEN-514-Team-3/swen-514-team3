import importlib.util
import json
import os
import unittest
from unittest.mock import Mock, patch
from pathlib import Path
from botocore.exceptions import ClientError, EndpointConnectionError

spec = importlib.util.spec_from_file_location("handler", Path(__file__).parents[1] / "lambda" / "handler.py")
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


class DraftTests(unittest.TestCase):
    def setUp(self):
        self.client = Mock()
        self.client.converse.return_value = {
            "stopReason": "end_turn",
            "output": {"message": {"content": [{"text": "Summary\nTeam reviewed login.\nProposed action items\nAlex: test logout; due date: Needs confirmation"}]}},
        }
        handler._client = self.client
        self.env = patch.dict(os.environ, {"BEDROCK_MODEL_ID": "amazon.nova-micro-v1:0"})
        self.env.start()
        self.addCleanup(self.env.stop)

    def call(self, body=None, authenticated=True):
        event = {"routeKey": "POST /ai-sample", "body": json.dumps(body if body is not None else {"text": "Alex will test logout.", "approved": True})}
        if authenticated:
            event["requestContext"] = {"authorizer": {"jwt": {"claims": {"sub": "test-user"}}}}
        result = handler.lambda_handler(event, None)
        return result["statusCode"], json.loads(result["body"])

    def test_success_calls_real_sdk_interface_with_bounded_generation(self):
        status, body = self.call()
        self.assertEqual(status, 200)
        self.assertEqual(body["service"], "amazon-bedrock")
        self.assertEqual(body["reviewStatus"], "needs-review")
        self.assertIn("Needs confirmation", body["result"])
        kwargs = self.client.converse.call_args.kwargs
        self.assertEqual(kwargs["modelId"], "amazon.nova-micro-v1:0")
        self.assertEqual(kwargs["inferenceConfig"]["maxTokens"], 800)

    def test_authentication_required_before_model_call(self):
        self.assertEqual(self.call(authenticated=False)[0], 401)
        self.client.converse.assert_not_called()

    def test_invalid_input_never_calls_model(self):
        for body in ([], {"text": " "}, {"text": 123}, {"text": "notes", "approved": False}, {"text": "x" * 12001, "approved": True}):
            self.assertEqual(self.call(body)[0], 400)
        self.client.converse.assert_not_called()

    def test_invalid_json(self):
        event = {"routeKey": "POST /ai-sample", "body": "{", "requestContext": {"authorizer": {"jwt": {"claims": {"sub": "test"}}}}}
        self.assertEqual(handler.lambda_handler(event, None)["statusCode"], 400)

    def test_model_access_failure_and_throttling(self):
        for code, status in (("AccessDeniedException", 503), ("ValidationException", 503), ("ThrottlingException", 429)):
            self.client.converse.side_effect = ClientError({"Error": {"Code": code, "Message": "sensitive service detail"}}, "Converse")
            actual, body = self.call()
            self.assertEqual(actual, status)
            self.assertNotIn("sensitive service detail", body["error"])

    def test_timeout(self):
        self.client.converse.side_effect = EndpointConnectionError(endpoint_url="https://example.invalid")
        self.assertEqual(self.call()[0], 504)

    def test_blocked_truncated_and_empty_output_are_not_success(self):
        for reason in ("max_tokens", "content_filtered", "guardrail_intervened"):
            self.client.converse.return_value["stopReason"] = reason
            self.assertEqual(self.call()[0], 502)
        self.client.converse.return_value = {"stopReason": "end_turn", "output": {"message": {"content": []}}}
        self.assertEqual(self.call()[0], 502)

    def test_health_does_not_call_bedrock(self):
        self.assertEqual(handler.lambda_handler({"routeKey": "GET /health"}, None)["statusCode"], 200)
        self.client.converse.assert_not_called()


if __name__ == "__main__":
    unittest.main()
