output "pool_id" { value = aws_cognito_user_pool.app.id }
output "client_id" { value = aws_cognito_user_pool_client.browser.id }
output "domain" {
  value = "https://${aws_cognito_user_pool_domain.app.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}
output "issuer" {
  value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.app.id}"
}
