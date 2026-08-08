package policy

import rego.v1

# Co-located with linear-board-assistant-guardrails.rego.
# Run via: opa test policies/

test_allow_gh_read if {
	not approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "gh api repos/acme/app/contents/README.md"},
	}}
}

test_deny_rm_rf if {
	approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "rm -rf /tmp/work"},
	}}
}

test_allow_gh_pr_create if {
	not approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "gh pr create --title x --body y"},
	}}
}

test_allow_linear_comment if {
	not approval_required with input as {"tool": {
		"name": "linear-integration_create_comment",
		"arguments": {"issueId": "CORE-42", "body": "stage output"},
	}}
}

test_allow_slack_notify if {
	not approval_required with input as {"tool": {
		"name": "slack-integration_post_message",
		"arguments": {"channel": "#aiden-sdlc", "text": "done"},
	}}
}

test_create_agent_not_intervention if {
	not approval_required with input as {"tool": {
		"name": "create_agent",
		"arguments": {"agent_name": "x", "goal": "y"},
	}}
}

test_deny_gh_pr_merge if {
	approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "gh pr merge 12 --merge"},
	}}
}

test_deny_gh_workflow_run if {
	approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "gh workflow run ci.yml"},
	}}
}
