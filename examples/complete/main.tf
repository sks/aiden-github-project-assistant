# First-time demo: all-in-one wrapper.
# For production, use the repo root module with shared foundation + integrations.

module "linear_board_assistant" {
  source = "../../wrappers/all-in-one"

  openai_api_key = var.openai_api_key
  linear_api_key = var.linear_api_key
  github_token   = var.github_token

  model_name = var.model_name
  model_id   = var.model_id

  default_team_key              = var.default_team_key
  default_project_url           = var.default_project_url
  linear_trigger_label          = var.linear_trigger_label
  webhook_repository_full_names = var.webhook_repository_full_names

  enable_linear_webhook       = true
  enable_github_webhook       = true
  enable_implement            = true
  enable_pr_merged_webhook    = true
  enable_status_poll_schedule = true

  enable_slack_notify  = var.enable_slack_notify
  slack_bot_token      = var.slack_bot_token
  slack_notify_channel = var.slack_notify_channel

  webhook_trigger_base_url = "${trimsuffix(var.stackgen_url, "/")}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
