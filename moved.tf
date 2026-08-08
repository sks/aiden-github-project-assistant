# Preserve the resources created by the initial Linear-only v0.2 preview while
# separating stable persona DNA from tracker adapters.

moved {
  from = sg_agent.linear_board_assistant
  to   = sg_agent.board_sdlc_assistant
}

moved {
  from = sg_agent_budget.linear_board_assistant
  to   = sg_agent_budget.board_sdlc_assistant
}

moved {
  from = sg_runbook_sop.item_assist
  to   = sg_runbook_sop.linear_item_assist[0]
}

moved {
  from = sg_workflow.item_assist
  to   = sg_workflow.linear_item_assist[0]
}

moved {
  from = terraform_data.persona_length_guard["linear-board-assistant.md"]
  to   = terraform_data.persona_length_guard["github-project-assistant.md"]
}
