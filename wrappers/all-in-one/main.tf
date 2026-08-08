# Convenience wrapper: OpenAI model stack + Linear + optional Slack + optional GitHub,
# then the Linear board assistant. Prefer the repo root module once you already have
# foundation + integrations.

locals {
  suffix          = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"
  provision_slack = var.enable_slack_notify && trimspace(var.slack_bot_token) != ""
  want_github     = var.enable_github || var.enable_implement
}

resource "sg_secret" "openai" {
  name        = "aiden-lba-openai-vault${local.suffix}"
  description = "OpenAI API key for Linear Board Assistant demo"
  category    = "LLM"
  subcategory = "openai"
  metadata = {
    OPENAI_API_KEY = var.openai_api_key
  }
}

resource "sg_guild_model_provider" "openai" {
  name            = "aiden-lba-openai${local.suffix}"
  provider_type   = "openai"
  token_reference = sg_secret.openai.name
}

resource "sg_guild_model" "primary" {
  name          = var.model_name
  provider_name = sg_guild_model_provider.openai.name
  model_id      = var.model_id != "" ? var.model_id : var.model_name
  good_for_task = "tool_calling"
}

resource "sg_secret" "github" {
  count = local.want_github ? 1 : 0

  name        = "aiden-lba-github-vault${local.suffix}"
  description = "GitHub PAT for Research + implement PRs"
  category    = "SCM"
  subcategory = "github"
  metadata = {
    provider = "github"
    token    = var.github_token
  }
}

module "assistant" {
  source = "../.."

  model_names = [sg_guild_model.primary.name]

  # Linear (board of truth) — provisioned from an inline api key here.
  linear_api_key = var.linear_api_key

  # Slack (notify only)
  enable_slack_notify  = var.enable_slack_notify
  slack_bot_token      = local.provision_slack ? var.slack_bot_token : ""
  slack_notify_channel = var.slack_notify_channel

  # GitHub (Research + optional implement PR)
  enable_github    = local.want_github
  github_secret_id = local.want_github ? sg_secret.github[0].id : ""

  default_team_key              = var.default_team_key
  linear_trigger_label          = var.linear_trigger_label
  webhook_repository_full_names = var.webhook_repository_full_names

  enable_linear_webhook       = var.enable_linear_webhook
  enable_implement            = var.enable_implement
  enable_pr_merged_webhook    = var.enable_pr_merged_webhook
  enable_status_poll_schedule = var.enable_status_poll_schedule
  status_poll_cron            = var.status_poll_cron

  webhook_auto_advance     = true
  sdlc_chain               = true
  webhook_trigger_base_url = var.webhook_trigger_base_url
  webhook_trigger_org_id   = var.webhook_trigger_org_id
  agent_budget             = var.agent_budget
  name_suffix              = var.name_suffix
}
