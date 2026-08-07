# Hard rule — agent persona length cap.
#
# Aiden OS rejects any sg_agent register/update whose persona exceeds MaxPersonaChars
# (32000) runes — see stackgen-guild internal/guild/agentrouter/config.go. Applying an
# oversized persona returns HTTP 500 from Aiden OS, taints the resource, and
# every subsequent `tofu plan` re-runs the same broken update.
#
# This guard converts that runtime failure into a plan-time error: the
# precondition is evaluated against every `personas/*.md` file in this
# module, so an oversized file blocks `tofu plan` long before reaching
# `tofu apply`. Repo-wide enforcement also lives in:
#   - scripts/verify-persona-length.sh (wired into `make check` + CI persona-length job)
#   - tofu-provider-stackgen: sg_agent.persona schema maxlen should match MaxPersonaChars
#
# Discovery uses fileset() so newly added persona files are picked up without
# touching this file. terraform_data has no side effects; it just hosts the
# precondition.
resource "terraform_data" "persona_length_guard" {
  for_each = fileset("${path.module}/personas", "*.md")

  input = each.value

  lifecycle {
    precondition {
      condition = length(file("${path.module}/personas/${each.value}")) <= 32000
      error_message = format(
        "Persona personas/%s is %d chars; Aiden OS caps at 32000 (MaxPersonaChars). Trim the file before applying.",
        each.value,
        length(file("${path.module}/personas/${each.value}")),
      )
    }
  }
}
