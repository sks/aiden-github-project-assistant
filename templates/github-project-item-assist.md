Process exactly one GitHub Project item through board SDLC (and optional implement).

Orchestration: the parent may use ReAcTree `create_agent` (`task_type=terminal_calling`) with GitHub tools. That is expected.

**create_agent goal hygiene (mandatory):** do **not** write absolute filesystem paths (`/tmp`, `/workspace`, …) in the create_agent `goal` or `context`. The execution-surface guard treats those as local workspace signals and false-blocks `github-integration_execute_command`. Name files in goal prose without directories (e.g. `project_item.graphql`); put real paths only in tool arguments.

**`create_files` paths (mandatory):** `github-integration_create_files` requires **absolute** paths (e.g. `/tmp/project_item.graphql`, `/tmp/assist_comment.md`). Relative paths fail with `path must be absolute`. Then reference those abs paths in `execute_command` (`-F query=@/tmp/project_item.graphql`, `-F body=@/tmp/assist_comment.md`).

**First command (mandatory):** `gh api user -q .login`

## Inputs

- `project_url` (required for chat runs) — GitHub Projects v2 URL, e.g. `https://github.com/orgs/<org>/projects/<n>` or `https://github.com/users/<user>/projects/<n>`
- `issue_number` (required) — numeric issue number in the repository that owns / is linked to the Project item
- `repository` (optional) — `owner/name` when the issue is not obvious from context
- `auto_advance` (optional) — default `false` for chat. Webhook / status-poll runs use deployment default `${webhook_auto_advance}`.
- `sdlc_chain` (optional) — default from deployment `${sdlc_chain}`. When true, after each successful board stage hop Status and continue until Plan is done (then optional Implement).
- `pr_merged` (optional) — when `true`, run **Done completion** only (PR already merged by a human).
- `pull_request_number` (optional) — merged PR number when `pr_merged` is true.

### Webhook ingress (issue.created / issues.opened)

When started from the GitHub issues webhook:

1. Read `repository.full_name` and `issue.number` from the payload (do not invent them).
2. Set `project_url` to the deployment default: `${default_project_url}` (must be non-empty for webhook-enabled deployments).
3. Set `auto_advance` to `${webhook_auto_advance}` and `sdlc_chain` to `${sdlc_chain}` unless chat overrides.
4. If GraphQL fetch finds **no** Project item for this issue: **add** the issue to the Project (`addProjectV2ItemById` using the issue node id), set Status to `${stage_specify}`, then run **Specify**.
5. Otherwise proceed with the Status-matched stage (and chain if enabled).

### Status poll (cron)

Prefer Plan items whose Aiden Implement PR is already **merged** and missing a Done comment → set `pr_merged=true`. Otherwise pick at most one Research/Plan item missing a matching stage comment (or Plan ready for Implement). Prefer Plan over Research for board SDLC.

### PR merged webhook / Done completion

When `pr_merged` is true (PR webhook or poll):

1. Resolve the issue + Project item (do not invent Status).
2. Confirm the cited PR is merged (`gh api repos/…/pulls/<n> --jq .merged`).
3. If Status is already `${stage_done}` and a Done comment exists: reply idle and stop.
4. Else run **Done** (below): hop Status to `${stage_done}`, close the issue if open, post the Done comment. Do not Implement again.

## Column map (this deployment)

| Logical stage | Project Status name |
|---------------|---------------------|
| Specify | `${stage_specify}` |
| Research | `${stage_research}` |
| Plan | `${stage_plan}` |
| Done | `${stage_done}` |

Next-column chain: `${stage_specify}` → `${stage_research}` → `${stage_plan}`. Do **not** auto-advance from `${stage_plan}` until a human merges the Implement PR — then hop to `${stage_done}`.

## Auth / fetch contract (mandatory)

GitHub PAT / vault token must include **`repo`** plus **`read:project`** and **`project`** (Projects v2). Without project scopes, `gh api graphql` exits `1` and this run must stop.

### Preflight (once)

```bash
gh api user -q .login
gh api graphql -f query='query { viewer { login } }' --jq .data.viewer.login
```

If either fails, stop and report auth failure (include command stderr). Do not invent Status.

### Fetch issue + Status (use this pattern — no `#` on the shell command line)

`#` in a shell command is often treated as a comment when quoting is mangled inside the integration sidecar. **Never** put `#27` (or similar) in the `execute_command` string. Pass filters as GraphQL variables or omit the items `query` filter.

1. Issue via REST:

```bash
gh api "repos/$${OWNER}/$${REPO}/issues/$${ISSUE_NUMBER}" --jq '{number,title,body,html_url}'
```

1. Project item + Status via GraphQL file (user-owned project example).

Write the query with `create_files` to an **absolute** path such as `/tmp/project_item.graphql`, then:

```bash
# CRITICAL gh flag rules (wrong flags cause exit status 1 with opaque sidecar errors):
# - Use -F query=@/tmp/project_item.graphql  (capital F — only -F expands @file)
# - Never use -f query=@… — that sends the literal "@…" string as the GraphQL query
# - Use -f itemQuery=… (lowercase f) so a bare issue number stays a String, not Int
# - NEVER -F itemQuery=28 — capital F coerces digits to Int and GitHub returns:
#     Variable $itemQuery of type String! was provided invalid value / Could not coerce value 28 to String
# - Use -F projectNumber=… so the project number is typed as Int
# - Variable names in -F/-f must match the query file ($login / $projectNumber / $itemQuery) — not owner/number
# itemQuery is the bare issue number or "is:issue <n>" — never "#<n>"
gh api graphql \
  -F login="$${PROJECT_OWNER}" \
  -F projectNumber="$${PROJECT_NUMBER}" \
  -f itemQuery="$${ISSUE_NUMBER}" \
  -F query=@/tmp/project_item.graphql
```

If `itemQuery` typing keeps failing: omit `query:` / `itemQuery` entirely, list `items(first:100)`, and pick the node whose `content.number` matches. That is preferred over stopping.

1. **Fatal vs soft `gh` failures (do not treat every exit 1 the same):**
   - **Fatal (stop):** auth preflight failure; Project Status / item GraphQL failure after the unfiltered-items fallback; inability to POST the stage comment or Status hop after the stage body is ready. For those only: re-run **once** with `2>&1`, paste stderr, stop. Do not invent Status.
   - **Soft (continue — never trip the circuit):** Contents/raw/search reads during Research (or opportunistic reads during Plan). **One attempt only.** Non-zero exit → treat as `path: not in repo` (or unreachable) and move on. **Do not** re-run with `2>&1`. **Do not** batch multiple paths in one shell/`python` script. README links often point at gitignored local docs that are not on GitHub.
   - Prefer already-posted `### Aiden project assist — Research` / Specify comments over re-fetching the tree when Status is already Plan.

## Steps

1. Resolve owner/project number from `project_url`. Confirm `issue_number` (and `repository` if provided). For webhook runs, prefer payload fields over search.
2. Run **Auth / fetch contract** above. If the item is missing, add it and set Status `${stage_specify}` (see Webhook ingress).
3. Read Status from the single-select field named `Status`.
4. If `pr_merged` is true: run **Done** and stop (ignore column-matched Specify/Research/Plan).
5. Match Status to Specify / Research / Plan (case-sensitive against the table above). If Status is `${stage_done}`: idle. If no match: comment "unsupported Status" and stop.
6. Run **the matched stage** (see stage bodies below).

### Specify

Rewrite the issue into:

- Goal (1–2 sentences)
- In scope / out of scope
- Acceptance criteria (checklist)
- Open questions (if any)

Do **not** invent requirements that contradict the issue; mark assumptions clearly.

### Research

Using GitHub APIs only (contents, search, tree, README, recent commits/PRs as needed):

- Relevant paths / entry points
- Existing patterns to reuse
- Risks / unknowns
Cite `owner/repo` paths. No local `git clone`.

Fetch files **one at a time**. Prefer raw bytes to avoid base64 decode scripts:

```bash
gh api "repos/$${OWNER}/$${REPO}/contents/$${PATH}" \
  -H "Accept: application/vnd.github.raw"
```

**One attempt per path.** Non-zero exit → soft miss (`path: not in repo`); continue. Never re-run Contents fetches with `2>&1` (that is only for fatal auth/Status failures). Incomplete evidence is OK — say what was missing. If the tool returns `circuit is open`, stop new Contents probes and finish the stage from evidence already gathered (issue body + README + prior Aiden comments).

### Plan

Produce:

- Implementation steps (ordered)
- Files likely to change (best effort)
- Test plan
- Rollout / rollback notes (brief)

### Done

Only when the Implement PR is **merged** (never invent a merge):

- Hop Project Status to `${stage_done}` via GraphQL (`updateProjectV2ItemFieldValue` with the Done option id).
- Close the GitHub issue if it is still open (`gh api repos/OWNER/REPO/issues/N -X PATCH -F state=closed`). Prefer PRs that used `Fixes` so GitHub may already have closed it.
- Post `### Aiden project assist — Done` with the merged PR URL and **Status (after):** `${stage_done}`.
- Do not open another PR. Do not merge. Do not reopen closed issues.
- Keep the create_agent **goal** free of filesystem path strings; put absolute paths only in `create_files` / `execute_command` args.

1. Post the mandatory comment format from the persona (stage name, before/after Status, output, next human step).
   Write the comment body via `create_files` with an **absolute** `path` argument (process temp dir + a filename such as `assist_comment.md`), then post with capital **`-F body=@…`** or `gh issue comment --body-file …`. Never `-f body=@…` (posts the literal path string).
2. Advancement after a board stage:
   - If `auto_advance` is not true: leave Status unchanged; set **Status (after)** to the same as before.
   - If `auto_advance` is true and the stage succeeded: update the Project item Status to the next column once via GraphQL `updateProjectV2ItemFieldValue` (write the mutation with `create_files` absolute path; pass option IDs as `-F` variables — never embed `#` in the shell line). Never advance more than one hop. Never advance from `${stage_plan}` on board stages (Done hop is only for merged PRs).
3. **SDLC chain** (`sdlc_chain` true, deployment default `${sdlc_chain}`):
   - After a successful Specify with Status hopped to Research: **continue** and run Research in this same run.
   - After a successful Research with Status hopped to Plan: **continue** and run Plan in this same run.
   - After Plan: go to Implement only when `${enable_implement}` is true; otherwise stop.
   - Cap: at most Specify + Research + Plan (+ optional Implement) in one run. Do not loop forever. Done is a separate run after merge.
4. **Implement (MANDATORY when `${enable_implement}` is true):** after the Plan comment is posted in this run **or** when Status is `${stage_plan}` and a Plan comment already exists, you **must** open the PR in the **same run** before stopping. Do not end with only a Plan comment when implement is enabled.
   - Ground work in the Plan comment + any Research/Specify comments + issue body.
   - Create a feature branch from the default branch via GitHub API (Contents API / `gh api`; no local clone required).
   - Commit concrete file changes that match the Plan (e.g. new/updated markdown under `_posts/` for a blog repo). Prefer small, reviewable diffs.
   - Open a PR with `gh pr create`. In the PR body file use **`Fixes <issue URL>`** (not only Refs) so GitHub can auto-close the issue on merge — still put the link in the body file, never `#` on a fragile shell line. Use `-F body=@…` or `--body-file` with an absolute path from `create_files`.
   - Comment on the issue with the PR URL under `### Aiden project assist — Implement`.
   - Do **not** merge the PR. Leave Project Status on `${stage_plan}` until Done completion after merge.
   - If implement fails, comment the error under Implement and stop — do not pretend success.
5. Summarize in chat: issue URL, comments, Status hops, PR URL if any.

## Safety

- One issue per run.
- Board stages: comment + optional Status hop; chain when `sdlc_chain` is true.
- Implement (when enabled): branch + commits + open PR only — never merge, never force-push, never delete.
- Done (after human merge): Status → `${stage_done}`, close issue, Done comment — still never `gh pr merge`.
- Forbidden always: `gh pr merge`, force-push, destructive shell, changing unrelated Project fields, running CI dispatch.
