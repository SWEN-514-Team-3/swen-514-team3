import importlib.util
import json
import os
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('notification_handler', 'lambda/handler.py')
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)

class NotificationTests(unittest.TestCase):
    def setUp(self):
        self.sns, self.events = Mock(), Mock()
        self.sns.get_paginator.return_value.paginate.return_value = [{'Subscriptions': []}]
        self.sns.publish.return_value = {'MessageId': 'message'}
        self.sns.subscribe.return_value = {'SubscriptionArn': 'arn:subscription'}
        self.events.put_events.return_value = {'FailedEntryCount': 0, 'Entries': [{'EventId': 'event'}]}
        self.env = patch.dict(os.environ, {'RECAP_EVENT_SOURCE':'test.app','REMINDER_SNS_TOPIC_ARN':'topic','SNS_TOPIC_ARN':'topic'})
        self.env.start(); self.addCleanup(self.env.stop)
        self.sdk = patch.object(handler.boto3, 'client', side_effect=lambda name, **kwargs: self.sns if name == 'sns' else self.events)
        self.sdk.start(); self.addCleanup(self.sdk.stop)

    def call(self, body=None):
        return handler.handle_broadcast({'body':json.dumps(body if body is not None else {'summary':'Summary','recipients':['Alice@example.com']})}, None)

    def test_response_and_filtered_subscription(self):
        result = self.call()
        self.assertEqual(result['statusCode'],202)
        self.assertEqual(json.loads(result['body'])['status'],'queued')
        self.assertEqual(json.loads(self.sns.subscribe.call_args.kwargs['Attributes']['FilterPolicy']),{'recipient':['alice@example.com']})
        detail = json.loads(self.events.put_events.call_args.kwargs['Entries'][0]['Detail'])
        self.assertEqual(detail['recipients'],['alice@example.com'])

    def test_invalid_body_and_recipient_list(self):
        for body in [[], {'summary':'x','recipients':'a@example.com'}, {'summary':'x','recipients':['bad']}]:
            self.assertEqual(self.call(body)['statusCode'],400)
        self.events.put_events.assert_not_called()

    def test_confirmation_does_not_claim_delivery(self):
        self.sns.subscribe.return_value={'SubscriptionArn':'pending confirmation'}
        result=self.call()
        self.assertEqual(json.loads(result['body'])['status'],'confirmation_required')
        self.events.put_events.assert_not_called()

    def test_eventbridge_failure(self):
        self.events.put_events.return_value={'FailedEntryCount':1}
        self.assertEqual(self.call()['statusCode'],502)

    def test_unfiltered_legacy_subscription_blocks_publish(self):
        self.sns.get_paginator.return_value.paginate.return_value=[{'Subscriptions':[{'SubscriptionArn':'arn:sub','Endpoint':'other@example.com','Protocol':'email'}]}]
        self.sns.get_subscription_attributes.return_value={'Attributes':{}}
        self.assertEqual(self.call()['statusCode'],503)
        self.events.put_events.assert_not_called()

    def test_recap_publish_targets_recipients(self):
        handler.handle_recap_event({'detail':{'message':'Summary','recipients':['alice@example.com']}})
        self.assertEqual(json.loads(self.sns.publish.call_args.kwargs['MessageAttributes']['recipient']['StringValue']),['alice@example.com'])

    def test_reminder_targets_owner_only(self):
        with patch.object(handler,'database') as db:
            db.return_value.run.return_value=[('Task','2026-12-01','Alice','Alice@example.com','Meeting')]
            handler.send_reminders({})
        self.assertEqual(json.loads(self.sns.publish.call_args.kwargs['MessageAttributes']['recipient']['StringValue']),['alice@example.com'])

if __name__=='__main__': unittest.main()
