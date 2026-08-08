output "agent_name" {
  value = module.linear_board_assistant.agent_name
}

output "workflow_name" {
  value = module.linear_board_assistant.workflow_name
}

output "linear_integration_name" {
  value = module.linear_board_assistant.linear_integration_name
}

output "linear_webhook_ingress_payload_url" {
  value     = module.linear_board_assistant.linear_webhook_ingress_payload_url
  sensitive = true
}

output "linear_webhook_token" {
  value     = module.linear_board_assistant.linear_webhook_token
  sensitive = true
}

output "pr_webhook_ingress_payload_url" {
  value     = module.linear_board_assistant.pr_webhook_ingress_payload_url
  sensitive = true
}
