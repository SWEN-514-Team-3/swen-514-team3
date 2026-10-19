data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_cognito_user_pool" "app" {
  name                     = "${var.name}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  username_configuration { case_sensitive = false }
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}
resource "aws_cognito_user_pool_domain" "app" {
  domain       = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  user_pool_id = aws_cognito_user_pool.app.id
}
resource "aws_cognito_user_pool_client" "browser" {
  name                                 = "${var.name}-browser"
  user_pool_id                         = aws_cognito_user_pool.app.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["${var.website_url}/"]
  logout_urls                          = ["${var.website_url}/"]
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  access_token_validity                = 60
  id_token_validity                    = 60
  token_validity_units {
    access_token = "minutes"
    id_token     = "minutes"
  }
}
