module "frontend" {
  source = "./modules/frontend"

  name       = "${var.project_name}-frontend"
  source_dir = "${path.root}/.." # static site files live at the repo root
}
