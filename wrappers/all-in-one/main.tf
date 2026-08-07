# Convenience wrapper: OpenAI model stack + GitHub vault + composable project assistant.
# Prefer the repo root module once you already have foundation + GitHub integration.

locals {
  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"
}

resource "sg_secret" "openai" {
  name        = "aiden-gpa-openai-vault${local.suffix}"
  description = "OpenAI API key for GitHub Project Assistant demo"
  category    = "LLM"
  subcategory = "openai"
  metadata = {
    OPENAI_API_KEY = var.openai_api_key
  }
}

resource "sg_guild_model_provider" "openai" {
  name            = "aiden-gpa-openai${local.suffix}"
  provider_type   = "openai"
  token_reference = sg_secret.openai.name
}

resource "sg_guild_model" "primary" {
  name          = var.model_name
  provider_name = sg_guild_model_provider.openai.name
}

resource "sg_secret" "github" {
  name        = "aiden-gpa-github-vault${local.suffix}"
  description = "GitHub PAT for Projects + issues + PRs"
  category    = "SCM"
  subcategory = "github"
  metadata = {
    provider = "github"
    token    = var.github_token
  }
}

module "assistant" {
  source = "../.."

  model_names      = [sg_guild_model.primary.name]
  github_secret_id = sg_secret.github.id

  default_project_url           = var.default_project_url
  webhook_repository_full_names = var.webhook_repository_full_names
  enable_github_webhook         = var.enable_github_webhook
  enable_implement              = var.enable_implement
  enable_pr_merged_webhook      = var.enable_pr_merged_webhook
  enable_status_poll_schedule   = var.enable_status_poll_schedule
  status_poll_cron              = var.status_poll_cron
  webhook_auto_advance          = true
  sdlc_chain                    = true
  webhook_trigger_base_url      = var.webhook_trigger_base_url
  webhook_trigger_org_id        = var.webhook_trigger_org_id
  agent_budget                  = var.agent_budget
  name_suffix                   = var.name_suffix
}
