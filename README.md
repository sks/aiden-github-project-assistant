# Aiden Linear Board Assistant

OpenTofu / Terraform module that runs **board SDLC** on one **Linear** issue:

**Specify → Research → Plan → (optional) review PR → Done after human merge**

- **Board of truth:** Linear — workflow **state** hops + issue **comments** (evidence).
- **Notify only:** Slack — a short receipt after each stage. Never a trigger, never source of truth.
- **Optional implement:** the agent opens a **GitHub PR**; **humans merge**. Done after merge.

> **v0.2.0 is a breaking change.** Earlier versions drove **GitHub Projects** boards
> (`github-project-assistant`). If you are on that model, pin `?ref=v0.1.0`. This
> version replaces the board surface with Linear + Slack and renames the agent,
> workflow, variables, and outputs.

Derived from StackGen AIOS packaging; published here as a **community / personal**
surface under [`sks`](https://github.com/sks). Not an official StackGen product repo.
This repo is **self-contained** — it does not depend on `appcd-dev/solutions`; the
Linear and Slack integration modules are vendored under [`modules/`](modules/).

## Prerequisites

- An active **Aiden / StackGen** tenant (URL + token + org/project id)
- A **Linear** API key (`lin_api_…`) or OAuth credential provider, and a team with
  workflow states matching Specify / Research / Plan / Done (names are configurable)
- GitHub PAT with `repo` (for Research + the optional implement PR)
- (Optional) a Slack **bot token** (`xoxb-…`) and a channel for stage receipts
- OpenTofu ≥ 1.5 (or Terraform) and StackGen provider `>= 0.1.33, != 0.1.35, < 0.2.0`

## Easy path (all-in-one)

Creates the OpenAI model + Linear integration (+ optional Slack + GitHub vaults),
the agent, workflow, and webhooks:

```hcl
module "linear_board_assistant" {
  source = "github.com/sks/aiden-github-project-assistant//wrappers/all-in-one?ref=v0.2.0"

  openai_api_key = var.openai_api_key
  linear_api_key = var.linear_api_key
  github_token   = var.github_token

  default_team_key      = "SKS"
  enable_linear_webhook = true
  enable_implement      = true

  # Slack notify (optional)
  enable_slack_notify  = true
  slack_bot_token      = var.slack_bot_token
  slack_notify_channel = "#aiden-sdlc"

  webhook_repository_full_names = ["YOU/your-repo"]

  webhook_trigger_base_url = "${var.stackgen_url}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

Runnable sample: [`examples/complete`](examples/complete/).

```bash
cd examples/complete
cp terraform.tfvars.example terraform.tfvars   # fill secrets
tofu init && tofu plan && tofu apply
tofu output -raw linear_webhook_ingress_payload_url   # Linear webhook Payload URL
tofu output -raw linear_webhook_token
```

Register a **Linear webhook** (Settings → API → Webhooks) for **Issues** (created +
updated) pointing at `linear_webhook_ingress_payload_url`. When implement is on, also
register a GitHub **Pull request** webhook on `pr_webhook_ingress_payload_url`.

## Production path (composable)

When you already have foundation models and shared integrations:

```hcl
module "linear_board_assistant" {
  source = "github.com/sks/aiden-github-project-assistant?ref=v0.2.0"

  model_names                      = module.foundation.model_names
  existing_linear_integration_name = module.linear.integration_name
  existing_github_integration_name = module.github.integration_name
  existing_slack_integration_name  = module.slack.integration_name

  default_team_key      = "SKS"
  enable_linear_webhook = true
  enable_implement      = true

  enable_slack_notify  = true
  slack_notify_channel = "#aiden-sdlc"

  webhook_trigger_base_url = "${var.stackgen_url}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What it creates

| Resource | Default name |
|----------|----------------|
| Agent | `linear-board-assistant` |
| Workflow | `linear-item-assist` |
| Runbook SOP | `linear-item-assist` |
| Policy | `linear-board-assistant-guardrails` |
| Linear integration (optional) | `linear-board-assistant-linear` |
| Slack integration (optional) | `linear-board-assistant-slack` |
| GitHub integration (optional) | `linear-board-assistant-github` |
| Webhook (optional) | Linear Issue create/update |
| Webhook (optional) | GitHub PR merged → Done |
| Schedule (optional) | Merge-safety poll |

## Board rules

| Do | Don't |
| -- | ----- |
| One issue per run | Boil the ocean across the board |
| Comment evidence on the Linear issue | Keep findings only in chat |
| Hop workflow state one step at a time | Jump Specify → Done in silence |
| Open a PR for humans to merge | Auto-merge |
| Use Slack for receipts | Treat Slack as the board |

## Trigger map

| Human gesture | Signal |
|---------------|--------|
| Linear issue created | Linear webhook (Issue create) → Specify |
| Linear state moved | Linear webhook (Issue update) → matching stage |
| PR merged | GitHub Pull request webhook (or merge poll) → Done |
| Slack message | **Not a trigger** (notify only) |

## License

Apache-2.0. See [LICENSE](LICENSE).
