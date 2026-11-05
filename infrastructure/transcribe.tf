# bucket for temporary file use
resource "aws_s3_bucket" "recordings_bucket" {
  bucket = "audio-drop-bucket"

  tags = {
    Name = "MyBucket"
    Environment = "Dev"
  }
}

# folder recordings get dropped into
resource "aws_s3_object" "folder1" {
  bucket = aws_s3_bucket.recordings_bucket.id
  acl = "private"
  key = "recordings/"
}

# Combined iam policies for both transcribe & s3
resource "aws_iam_role_policy" "lambda_transcribe" {
  name = "${var.project_name}-transcribe-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "transcribe:ListTranscriptionJobs"
      ]
      Resource = "*"
    },
    {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.recordings_bucket.arn}/*"
    }
    ]
  })
}

resource "aws_security_group" "transcribe_endpoint" {
  name        = "${var.project_name}-transcribe-endpoint"
  description = "Transcribe PrivateLink HTTPS from application Lambda only"
  vpc_id      = module.networking.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "transcribe_https" {
  security_group_id            = aws_security_group.transcribe_endpoint.id
  referenced_security_group_id = module.networking.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "lambda_transcribe" {
  security_group_id            = module.networking.lambda_security_group_id
  referenced_security_group_id = aws_security_group.transcribe_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "transcribe" {
  vpc_id              = module.networking.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.transcribe"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.networking.private_subnet_ids
  security_group_ids  = [aws_security_group.transcribe_endpoint.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "transcribe:ListTranscriptionJobs"
      ]
      Resource  = "*"
      Condition = {
        ArnEquals = { "aws:PrincipalArn" = aws_iam_role.lambda.arn }
      }
    }]
  })
}

# create transcribe route
resource "aws_apigatewayv2_route" "transcribe" {
  api_id               = aws_apigatewayv2_api.http.id
  route_key            = "POST /transcribe"
  target               = "integrations/${aws_apigatewayv2_integration.transcribe_lambda.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["openid"]
}