# Runbook

## Local development

Set `HACKATHON_COMPETITOR_HOME` to a writable directory, then run migrations,
tests, and `doctor`. The fixture E2E is offline and makes no external writes.

## Plow deployment

For a self-hosted run, use the public CLI to log in, list lines, and mint a
line-scoped credential; Compose loads it through `env_file` and keeps it out of
the image and Git. For a hosted/cloud run, do not run `login` or `mint` in the
tenant VM: the Plow provisioner supplies `PLOW_API_BASE` and the tenant
identity, and may proxy authentication without exposing a raw bearer there.
The hosted registry/provisioner handoff is Plow-side, not a command in the
public `plow-agents` CLI. Verified status is a separate eligibility request;
the agent is eligible for the competition only after the Agent Index shows it
in the Verified section.

## Operational chat channel

The live product channel for this installation is its Plow Chat phone line.
The provider/channel is determined by the provisioned line and current plugin
configuration. A browser ChatGPT or custom-GPT conversation is a separate
interface; it does not prove that Plow Chat received or executed the message.
End-to-end acceptance tests must use the provisioned line and then verify the
container's durable state.

## Recovery

Missions and tasks are persisted in SQLite. On process restart, stale running
tasks are changed to retryable failure and can be resumed within their retry
limit. Never delete the database to hide a failed task.

When a live source does not contain enough official rule information, mission
creation returns an inspectable `BLOCKED` status with `quality_blockers` rather
than a traceback. Add or refresh from a richer official rules source; do not
override the gate with community claims.

## GitHub runtime authentication

The container uses `GH_CONFIG_DIR=/var/lib/hermes/.config/gh`, inside the
persistent Hermes volume. Authenticate interactively with `gh auth login`; never
bake GitHub credentials into the image or commit them. When the container has no
OS keyring, `gh` stores its credential in `hosts.yml`; keep that file owned by the
Hermes runtime user with mode `0600` and keep the containing directory
owner-only. Use `gh auth logout` to revoke the stored session.

Authentication proves identity and access, but it is not action approval. Push,
PR creation, deployment, Agent Index updates, verification requests, and final
submission remain approval-bound external actions.

The GitHub identity boundary is installation-scoped: one Joust installation
and its persistent Hermes volume retain one connected GitHub account. A fresh
volume starts disconnected and must never inherit a creator's `~/.config/gh`
or any image-baked configuration. This supports one instance per user. A
single hosted instance shared by many phone-line users cannot provide separate
per-user GitHub identities with the current `gh` model; that future shape
requires per-user OAuth or GitHub App authorization.

Mission state, artifacts, default workspaces, and newly generated projects
are stored below the tenant home. `joust-it` and `mission create` use that
location automatically; an explicit existing-project path is the only normal
way to point a mission outside it. Provisioning supplies `AGENT_ID` and the
Plow credential at runtime, so neither is baked into the image.

## Submission safety

Joust may prepare artifacts automatically. Publishing or submitting remains
a confirmation-gated external action.
