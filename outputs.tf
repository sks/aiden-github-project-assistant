output "agent_name" {
  description = "Shared tracker-agnostic Board SDLC agent name."
  value       = sg_agent.board_sdlc_assistant.name
}

output "workflow_name" {
  description = "Compatibility alias: Linear workflow when enabled, otherwise GitHub Projects workflow."
  value = nonsensitive(local.want_linear ? sg_workflow.linear_item_assist[0].name : (
    local.want_github ? sg_workflow.github_project_item_assist[0].name : ""
  ))
}

output "linear_workflow_name" {
  value = try(sg_workflow.linear_item_assist[0].name, "")
}

output "github_project_workflow_name" {
  value = try(sg_workflow.github_project_item_assist[0].name, "")
}

output "linear_integration_name" {
  value = nonsensitive(local.resolved_linear_integration_name)
}

output "slack_integration_name" {
  value = nonsensitive(local.resolved_slack_integration_name)
}

output "github_integration_name" {
  value = nonsensitive(local.resolved_github_integration_name)
}

output "policy_ids" {
  value = { guardrails = sg_policy.guardrails.id }
}

output "stage_names" {
  value = var.stage_names
}

output "default_project_url" {
  value = var.default_project_url
}

output "default_team_key" {
  value = var.default_team_key
}

output "linear_webhook_id" {
  value = try(sg_webhook.linear_item_assist[0].id, "")
}

output "linear_webhook_token" {
  value     = try(sg_webhook.linear_item_assist[0].token, "")
  sensitive = true
}

output "linear_webhook_ingress_payload_url" {
  sensitive = true
  value = (
    var.enable_linear_webhook &&
    trimspace(var.webhook_trigger_base_url) != "" &&
    try(trimspace(sg_webhook.linear_item_assist[0].token), "") != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.linear_item_assist[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "github_webhook_id" {
  value = try(sg_webhook.github_project_item_assist[0].id, "")
}

output "github_webhook_token" {
  value     = try(sg_webhook.github_project_item_assist[0].token, "")
  sensitive = true
}

output "github_webhook_ingress_payload_url" {
  sensitive = true
  value = (
    var.enable_github_webhook &&
    trimspace(var.webhook_trigger_base_url) != "" &&
    try(trimspace(sg_webhook.github_project_item_assist[0].token), "") != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_project_item_assist[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "webhook_id" {
  description = "v0.1 compatibility alias for the GitHub Issues webhook."
  value       = try(sg_webhook.github_project_item_assist[0].id, "")
}

output "webhook_token" {
  description = "v0.1 compatibility alias for the GitHub Issues webhook token."
  value       = try(sg_webhook.github_project_item_assist[0].token, "")
  sensitive   = true
}

output "webhook_ingress_payload_url" {
  description = "v0.1 compatibility alias for the GitHub Issues ingress URL."
  sensitive   = true
  value = (
    var.enable_github_webhook &&
    trimspace(var.webhook_trigger_base_url) != "" &&
    try(trimspace(sg_webhook.github_project_item_assist[0].token), "") != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_project_item_assist[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "linear_pr_webhook_ingress_payload_url" {
  sensitive = true
  value = (
    local.enable_linear_pr_webhook &&
    trimspace(var.webhook_trigger_base_url) != "" &&
    try(trimspace(sg_webhook.linear_item_assist_prs[0].token), "") != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.linear_item_assist_prs[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "github_pr_webhook_ingress_payload_url" {
  sensitive = true
  value = (
    local.enable_github_pr_webhook &&
    trimspace(var.webhook_trigger_base_url) != "" &&
    try(trimspace(sg_webhook.github_project_item_assist_prs[0].token), "") != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_project_item_assist_prs[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "pr_webhook_ingress_payload_url" {
  description = "Compatibility alias: Linear PR webhook when enabled, otherwise GitHub Projects PR webhook."
  sensitive   = true
  value = local.enable_linear_pr_webhook ? (
    trimspace(var.webhook_trigger_base_url) == "" ? null : format(
      "%s/api/v1/webhooks/trigger?apiKey=%s%s",
      trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
      urlencode(sg_webhook.linear_item_assist_prs[0].token),
      trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
    )
    ) : (
    local.enable_github_pr_webhook && trimspace(var.webhook_trigger_base_url) != "" ? format(
      "%s/api/v1/webhooks/trigger?apiKey=%s%s",
      trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
      urlencode(sg_webhook.github_project_item_assist_prs[0].token),
      trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
    ) : null
  )
}

output "pr_webhook_token" {
  description = "Compatibility alias: Linear PR webhook token when enabled, otherwise GitHub Projects PR webhook token."
  sensitive   = true
  value = local.enable_linear_pr_webhook ? try(sg_webhook.linear_item_assist_prs[0].token, "") : (
    local.enable_github_pr_webhook ? try(sg_webhook.github_project_item_assist_prs[0].token, "") : ""
  )
}

output "enable_slack_notify" {
  value = var.enable_slack_notify
}
