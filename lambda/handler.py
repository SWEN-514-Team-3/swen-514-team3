import json

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }

def lambda_handler(event, context):
    route = event.get("routeKey", "")
    if route == "GET /health":
        return response(200, {
            "status": "ok",
            "service": "meeting-momentum-api",
            "message": "API Gateway and Lambda are connected."
        })

    if route == "POST /ai-sample":
        try:
            raw_body = event.get("body") or "{}"
            body = json.loads(raw_body)
            sample_text = body.get("text", "")
            if not isinstance(sample_text, str) or not sample_text.strip():
                return response(400, {"error": "The 'text' field must be a non-empty string."})
            return response(200, {
                "status": "received",
                "service": "demo-placeholder", # placeholder, replace with selected AI service integration
                "reviewStatus": "needs-review",
                "result": "AI integration is not configured yet.",
                "inputLength": len(sample_text)
            })
        except (json.JSONDecodeError, TypeError):
            return response(400, {"error": "Request body must be valid JSON."})

    return response(404, {"error": "Route not found."})
