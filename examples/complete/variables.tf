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

variable "github_token" {
  type        = string
  sensitive   = true
  description = "PAT with repo + read:project + project"
}

variable "default_project_url" {
  type = string
}

variable "webhook_repository_full_names" {
  type    = list(string)
  default = []
}
