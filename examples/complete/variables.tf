variable "stackgen_url" {
  type        = string
  description = "Aiden / StackGen tenant URL, e.g. https://ai.dev.stackgen.com"
}

variable "stackgen_token" {
  type        = string
  sensitive   = true
  description = "StackGen API token"
}

variable "stackgen_project_id" {
  type        = string
  description = "Org / project id for webhook orgId query"
}

variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "linear_api_key" {
  type        = string
  sensitive   = true
  description = "Linear personal API key (lin_api_…) — board of truth"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "PAT with `repo` scope for Research + implement PRs"
  default     = ""
}

variable "default_team_key" {
  type        = string
  description = "Linear team key, e.g. SKS"
}

variable "model_name" {
  type        = string
  description = "Registered model name for the agent."
  default     = "gpt-5.4-2026-03-05"
}

variable "model_id" {
  type        = string
  description = "Underlying provider model id (defaults to model_name when empty)."
  default     = ""
}

variable "linear_trigger_label" {
  type    = string
  default = ""
}

variable "webhook_repository_full_names" {
  type    = list(string)
  default = []
}

variable "enable_slack_notify" {
  type    = bool
  default = false
}

variable "slack_bot_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "slack_notify_channel" {
  type    = string
  default = ""
}
