# Aiden GitHub Project Assistant

OpenTofu / Terraform module that runs **board SDLC** on one GitHub Project item:

**Specify → Research → Plan → (optional) review PR → Done after human merge**

Evidence lands as structured **issue comments**. The agent may open a PR; **humans merge**.

This is the **easy path**. For why the pieces exist (webhooks vs card drag vs PR merge, `-F` vs `-f`, HITL), read [Aiden the Hard Way](https://productionnotes.dev/blog/from-vague-github-issue-to-pr-with-aiden/).

Derived from StackGen AIOS packaging; published here as a **community / personal** surface under [`sks`](https://github.com/sks). Not an official StackGen product repo.

## Prerequisites

- An active **Aiden / StackGen** tenant (URL + token + org/project id)
- GitHub PAT with `repo`, `read:project`, and `project`
- OpenTofu ≥ 1.5 (or Terraform) and StackGen provider `>= 0.1.33, != 0.1.35, < 0.2.0`

## Easy path (all-in-one)

Creates OpenAI vault + model, GitHub vault + integration, agent, workflow, webhooks, and status poll:

```hcl
module "github_project_assistant" {
  source = "github.com/sks/aiden-github-project-assistant//wrappers/all-in-one?ref=v0.1.0"

  openai_api_key      = var.openai_api_key
  github_token        = var.github_token
  default_project_url = "https://github.com/users/YOU/projects/1"

  webhook_repository_full_names = ["YOU/your-repo"]
  enable_implement              = true
  enable_status_poll_schedule   = true

  webhook_trigger_base_url = "${var.stackgen_url}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

Runnable sample: [`examples/complete`](examples/complete/).

```bash
cd examples/complete
cp terraform.tfvars.example terraform.tfvars   # fill secrets
tofu init && tofu plan && tofu apply
tofu output -raw webhook_ingress_payload_url   # Issues webhook Payload URL
tofu output -raw webhook_token
```

Register **Issues** (opened) on the issues ingress. When implement is on, also register **Pull request** events on `pr_webhook_ingress_payload_url`.

## Production path (composable)

When you already have foundation models and a GitHub integration:

```hcl
module "github_project_assistant" {
  source = "github.com/sks/aiden-github-project-assistant?ref=v0.1.0"

  model_names                      = module.foundation.model_names
  existing_github_integration_name = module.github.integration_name

  default_project_url           = "https://github.com/users/YOU/projects/1"
  webhook_repository_full_names = ["YOU/your-repo"]

  enable_github_webhook       = true
  enable_implement            = true
  enable_pr_merged_webhook    = true
  enable_status_poll_schedule = true

  webhook_trigger_base_url = "${var.stackgen_url}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What it creates

| Resource | Default name |
|----------|----------------|
| Agent | `github-project-assistant` |
| Workflow | `github-project-item-assist` |
| Runbook SOP | `github-project-item-assist` |
| Policy | `github-project-assistant-guardrails` |
| Webhook (optional) | Issues opened |
| Webhook (optional) | PR merged → Done |
| Schedule (optional) | Status poll |

## Board rules

| Do | Don’t |
| -- | ----- |
| One issue per run | Boil the ocean across the board |
| Comment evidence on the issue | Keep findings only in chat |
| Hop Status one column at a time | Jump Specify → Done in silence |
| Open a PR for humans to merge | Auto-merge |

## Trigger map

| Human gesture | Signal |
|---------------|--------|
| Issue opened | Issues webhook |
| Card drag on Projects v2 | Status poll schedule (not an `issues` event) |
| PR merged | Pull request webhook (or poll fallback) |

## License

Apache-2.0. See [LICENSE](LICENSE).
