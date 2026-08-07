# First-time demo: all-in-one wrapper.
# For production, use the repo root module with shared foundation + GitHub integration.

module "github_project_assistant" {
  source = "../../wrappers/all-in-one"

  openai_api_key = var.openai_api_key
  github_token   = var.github_token

  default_project_url           = var.default_project_url
  webhook_repository_full_names = var.webhook_repository_full_names

  enable_github_webhook       = true
  enable_implement            = true
  enable_pr_merged_webhook    = true
  enable_status_poll_schedule = true
  status_poll_cron            = "*/5 * * * *"

  webhook_trigger_base_url = "${trimsuffix(var.stackgen_url, "/")}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
