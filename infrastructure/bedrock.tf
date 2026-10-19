variable "bedrock_model_id" {
  description = "Regional Amazon Nova model used for meeting drafts."
  type        = string
  default     = "amazon.nova-micro-v1:0"
  validation {
    condition     = var.bedrock_model_id == "amazon.nova-micro-v1:0"
    error_message = "This demo currently supports the regional Nova Micro model."
  }
}

resource "aws_security_group" "bedrock_endpoint" {
  name        = "${var.project_name}-bedrock-endpoint"
  description = "Bedrock PrivateLink HTTPS from application Lambda only"
  vpc_id      = module.networking.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "bedrock_https" {
  security_group_id            = aws_security_group.bedrock_endpoint.id
  referenced_security_group_id = module.networking.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_egress_rule" "lambda_bedrock" {
  security_group_id            = module.networking.lambda_security_group_id
  referenced_security_group_id = aws_security_group.bedrock_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = module.networking.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.networking.private_subnet_ids
  security_group_ids  = [aws_security_group.bedrock_endpoint.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "bedrock:InvokeModel"
      Resource  = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
      Condition = { ArnEquals = { "aws:PrincipalArn" = aws_iam_role.lambda.arn } }
    }]
  })
}
resource "aws_iam_role_policy" "lambda_bedrock" {
  name = "${var.project_name}-bedrock-drafts"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "bedrock:InvokeModel"
      Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
    }]
  })
}
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http.id
  name             = "cognito-users"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [module.authentication.client_id]
    issuer   = module.authentication.issuer
  }
}
resource "aws_apigatewayv2_route" "ai" {
  api_id               = aws_apigatewayv2_api.http.id
  route_key            = "POST /ai-sample"
  target               = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["openid"]
}
output "bedrock_model_id" { value = var.bedrock_model_id }

moved {
  from = aws_apigatewayv2_route.meetings["POST /ai-sample"]
  to   = aws_apigatewayv2_route.ai
}
