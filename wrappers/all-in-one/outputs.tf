output "agent_name" {
  value = module.assistant.agent_name
}

output "workflow_name" {
  value = module.assistant.workflow_name
}

output "model_name" {
  value = sg_guild_model.primary.name
}

output "linear_integration_name" {
  value = module.assistant.linear_integration_name
}

output "slack_integration_name" {
  value = module.assistant.slack_integration_name
}

output "github_integration_name" {
  value = module.assistant.github_integration_name
}

output "linear_webhook_token" {
  value     = module.assistant.linear_webhook_token
  sensitive = true
}

output "linear_webhook_ingress_payload_url" {
  value     = module.assistant.linear_webhook_ingress_payload_url
  sensitive = true
}

output "pr_webhook_token" {
  value     = module.assistant.pr_webhook_token
  sensitive = true
}

output "pr_webhook_ingress_payload_url" {
  value     = module.assistant.pr_webhook_ingress_payload_url
  sensitive = true
}
