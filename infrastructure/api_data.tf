# Lets the API Lambda read the database password from Secrets Manager.
# The Lambda runs in private subnets with no internet access, so it reaches
# Secrets Manager through this VPC endpoint (same pattern as Bedrock).
resource "aws_security_group" "secretsmanager_endpoint" {
  name        = "${var.project_name}-secretsmanager-endpoint"
  description = "Secrets Manager HTTPS from application Lambda only"
  vpc_id      = module.networking.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "secretsmanager_https" {
  security_group_id            = aws_security_group.secretsmanager_endpoint.id
  referenced_security_group_id = module.networking.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "lambda_secretsmanager" {
  security_group_id            = module.networking.lambda_security_group_id
  referenced_security_group_id = aws_security_group.secretsmanager_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.networking.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.networking.private_subnet_ids
  security_group_ids  = [aws_security_group.secretsmanager_endpoint.id]
}

# Routes for adding and updating action items (signed-in users only).
resource "aws_apigatewayv2_route" "action_items_write" {
  for_each = toset([
    "POST /action-items",
    "PATCH /action-items/{id}"
  ])

  api_id             = aws_apigatewayv2_api.http.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}
