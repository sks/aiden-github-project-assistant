variable "openai_api_key" {
  description = "OpenAI API key. Creates an LLM vault secret + OpenAI model provider + named model."
  type        = string
  sensitive   = true
}

variable "linear_api_key" {
  description = "Linear personal API key (lin_api_…). Provisions the Linear integration (board of truth)."
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub PAT with `repo` scope for Research + implement PRs. Required when enable_github or enable_implement is true."
  type        = string
  sensitive   = true
  default     = ""
}

variable "model_name" {
  description = "Registered model name for the agent. Use a model your Aiden tenant already knows."
  type        = string
  default     = "gpt-5.4-2026-03-05"
}

variable "model_id" {
  description = "Underlying provider model id. Defaults to model_name when empty."
  type        = string
  default     = ""
}

variable "default_team_key" {
  description = "Linear team key used for webhook / poll runs, e.g. CORE or SKS."
  type        = string
}

variable "linear_trigger_label" {
  description = "Optional Linear label that gates webhook runs (empty = any issue on the team)."
  type        = string
  default     = ""
}

variable "enable_slack_notify" {
  description = "Post a short stage receipt to Slack after each stage."
  type        = bool
  default     = false
}

variable "slack_bot_token" {
  description = "Slack Bot Token (xoxb-…). Required when enable_slack_notify is true and no shared Slack integration exists."
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_notify_channel" {
  description = "Slack channel name or ID for stage receipts (e.g. #aiden-sdlc)."
  type        = string
  default     = ""
}

variable "enable_github" {
  description = "Attach a GitHub integration for Research (repo APIs). Implied true when enable_implement is true."
  type        = bool
  default     = true
}

variable "webhook_repository_full_names" {
  description = "Optional allowlist of owner/name repositories for the PR-merge webhook."
  type        = list(string)
  default     = []
}

variable "enable_linear_webhook" {
  description = "Create the Linear Issue create/update webhook ingress."
  type        = bool
  default     = true
}

variable "enable_implement" {
  description = "After Plan, open a review PR on GitHub (never merge)."
  type        = bool
  default     = true
}

variable "enable_pr_merged_webhook" {
  description = "Create the PR-merge webhook so the Linear state hops to Done after a human merge."
  type        = bool
  default     = true
}

variable "enable_status_poll_schedule" {
  description = "Fallback poll for a missed PR-merge webhook."
  type        = bool
  default     = false
}

variable "status_poll_cron" {
  description = "Five-field cron (UTC) for the fallback poll."
  type        = string
  default     = "*/15 * * * *"
}

variable "webhook_trigger_base_url" {
  description = "StackGen HTTP API origin for webhook payload URLs, e.g. https://ai.dev.stackgen.com/guild"
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional orgId query on webhook ingress URLs (provider project_id)."
  type        = string
  default     = ""
}

variable "agent_budget" {
  description = "Daily USD budget for the agent."
  type        = number
  default     = 20
}

variable "name_suffix" {
  description = "Optional suffix for resource names."
  type        = string
  default     = ""
}
