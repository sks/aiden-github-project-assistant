package policy

import rego.v1

# Co-located with github-project-assistant-guardrails.rego.
# Run via: opa test policies/

test_allow_gh_graphql if {
	not approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "gh api graphql -f query='query { viewer { login } }'"},
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

test_create_agent_not_intervention if {
	not approval_required with input as {"tool": {
		"name": "create_agent",
		"arguments": {"agent_name": "x", "goal": "y"},
	}}
}

test_deny_gh_workflow_run if {
	approval_required with input as {"tool": {
		"name": "demo_execute_command",
		"arguments": {"command": "gh workflow run ci.yml"},
	}}
}
