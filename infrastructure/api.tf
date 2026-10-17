
# POST Method
resource "aws_apigatewayv2_route" "create_meeting" {
  api_id    = aws_apigatewayv2_api.meeting_momentum.id
  route_key = "POST /meetings"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

# GET Method
resource "aws_apigatewayv2_route" "get_meetings" {
  api_id    = aws_apigatewayv2_api.meeting_momentum.id
  route_key = "GET /meetings"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

# PUT Method
resource "aws_apigatewayv2_route" "update_meeting" {
  api_id    = aws_apigatewayv2_api.meeting_momentum.id
  route_key = "PUT /meetings/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

# DELETE Method
resource "aws_apigatewayv2_route" "delete_meeting" {
  api_id    = aws_apigatewayv2_api.meeting_momentum.id
  route_key = "DELETE /meetings/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}