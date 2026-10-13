module "frontend" {
  source = "./modules/frontend"
}

module "database" {
  source = "./modules/database"
  name   = "meeting-momentum"
}
