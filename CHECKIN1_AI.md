# Bedrock check-in demo

The approved Bedrock extension uses regional Amazon Nova Micro (`amazon.nova-micro-v1:0`) in us-east-1 through Converse. Transcribe remains the primary AI capability and is separate future work. AWS model reference: https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-amazon-nova-micro.html

Terraform configures model-scoped InvokeModel permission, the Cognito JWT authorizer for POST /ai-sample, and a private Bedrock runtime interface endpoint in both private subnets. No manual Bedrock console configuration is part of Setup. A foundation model is an AWS-managed service, not a model deployed by this project. Account restrictions or model access failures are surfaced as errors; no fake AI output is substituted. PrivateLink adds ongoing endpoint-hour and data charges, and model invocation is metered. Teardown removes the endpoint and associated project resources.

## Deploy and demonstrate

1. Run Setup with action=plan on feature/ai-demo using the same HaimarR state and account as the deployed application. Review the plan, then deploy with action=apply after review.
2. Open frontend_website_url over HTTPS. Sign in through Cognito, then open the meeting summary section. If an older session/token causes 401, log out and sign in again.
3. Use the included synthetic sample or paste approved notes (maximum 12,000 characters). Check the source-review box and generate a draft.
4. Show the model ID, meaningful summary, proposed actions, and editable draft. Review/correct descriptions, owners, and due dates. Nothing is saved to the database; per-action confirmation and persistence remain future work.
5. Demonstrate the handled invalid-input case by unchecking approval or submitting blank text. Changing source text clears approval and the previous draft.
6. Verify unauthenticated POST /ai-sample returns 401. GET /health remains a public diagnostic endpoint. Other unfinished meeting routes are unchanged.

For Check-in 1, rehearse Teardown and repeat Setup first. Arrive with the application environment undeployed and trigger Setup with apply while the grader watches. After that observed deployment, demonstrate frontend, backend /health, and real AI output from the browser. Prior deployments and screenshots cannot replace the live setup.

## Tests and limits

Run `node --test tests/auth.test.cjs tests/ai.test.cjs` and `python -m unittest discover -s tests -p test_bedrock.py` with boto3 installed. Terraform checks: init, fmt -check -recursive, validate, and authenticated plan. Mocked unit tests do not prove actual model access or network reachability. The deployed browser test must pass before claiming AI readiness.

The Lambda has bounded text input, 800 output tokens, one SDK attempt, and a 25-second timeout. Model access errors, throttling, blocked/incomplete output, and connectivity failures are handled. No prompt or token is logged. Session storage and the existing client library provide the bearer token; API Gateway validates issuer, audience, and the openid scope. Generated output uses textarea.value to avoid interpreting model text as HTML.

## Deployment configuration and transcription updates

Setup and Teardown both accept the optional GitHub environment variable `PROJECT_NAME` (for example, `mm-haimarr`). Use a different value for each independent deployment in the same AWS account and keep a separate `TF_STATE_KEY` for each. Names must start with a lowercase letter, contain lowercase letters/digits separated by single hyphens, and be at most 25 characters. Leaving it unset preserves `meeting-momentum`. Keep the value consistent between Setup and Teardown; changing it for deployed resources can cause replacements. Review a plan before migrating an existing environment. Recap event sources are also scoped by project name.

The Terraform `database_name` variable defaults to `meetingmomentum`; the database module exports the actual name to both application and database-init Lambdas. Changing this value may replace RDS. The S3 gateway endpoint now follows `aws_region`.

Transcription uploads return HTTP 202 with a `jobId`. The browser checks the authenticated `GET /transcribe/{jobId}` endpoint every three seconds, up to 15 minutes, and displays the completed transcript or a failure message. Jobs are scoped to the recordings bucket and the signed-in Cognito user. Closing the page stops browser polling but does not cancel the AWS job. Audio is still uploaded through API Gateway/Lambda, so existing payload-size limits apply. This change removes the wait for the complete transcription from the 25-second Lambda invocation; it does not remove upload-size limits.

Local transcription checks: `python -m unittest discover -s tests -p test_transcribe.py` and `node --test tests/transcribe.test.cjs`. After deployment, test a recording whose transcription takes longer than 25 seconds and confirm another user cannot retrieve its job.
