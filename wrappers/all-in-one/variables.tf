variable "openai_api_key" {
  description = "OpenAI API key. Creates an LLM vault secret + OpenAI model provider + named model."
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub PAT with repo + Projects v2 scopes (read:project, project)."
  type        = string
  sensitive   = true
}

variable "model_name" {
  description = "Registered model name for the agent. Use a model your Aiden tenant already knows."
  type        = string
  default     = "gpt-5.4-2026-03-05"
}

variable "default_project_url" {
  description = "GitHub Projects v2 URL used for webhook / status-poll runs."
  type        = string
}

variable "webhook_repository_full_names" {
  description = "Optional allowlist of owner/name repositories for webhook runs."
  type        = list(string)
  default     = []
}

variable "enable_github_webhook" {
  description = "Create the Issues webhook ingress."
  type        = bool
  default     = true
}

variable "enable_implement" {
  description = "After Plan, open a review PR (never merge)."
  type        = bool
  default     = true
}

variable "enable_pr_merged_webhook" {
  description = "Create PR-merge webhook so Status hops to Done after human merge."
  type        = bool
  default     = true
}

variable "enable_status_poll_schedule" {
  description = "Poll the Project for card drags / missed PR events."
  type        = bool
  default     = true
}

variable "status_poll_cron" {
  description = "Five-field cron (UTC) for the status poll."
  type        = string
  default     = "*/5 * * * *"
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
