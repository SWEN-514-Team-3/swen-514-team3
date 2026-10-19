module "frontend" {
  source = "./modules/frontend"
}

module "networking" {
  source = "./modules/networking"
  name   = var.project_name
}

module "database" {
  source            = "./modules/database"
  name              = var.project_name
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.database_security_group_id
}

module "lambda_test" {
  source                   = "./modules/lambda_test"
  name                     = var.project_name
  subnet_ids               = module.networking.private_subnet_ids
  security_group_id        = module.networking.lambda_security_group_id
  permissions_boundary_arn = var.lambda_permissions_boundary_arn
}

module "authentication" {
  source      = "./modules/authentication"
  name        = var.project_name
  website_url = module.frontend.website_url
}
resource "aws_s3_object" "auth_config" {
  bucket        = module.frontend.bucket_name
  key           = "auth-config.json"
  content_type  = "application/json"
  cache_control = "no-store"
  content = jsonencode({
    authority    = module.authentication.issuer
    domain       = module.authentication.domain
    client_id    = module.authentication.client_id
    redirect_uri = "${module.frontend.website_url}/"
  })
}
