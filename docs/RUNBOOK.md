# Runbook

## Local development

Set `HACKATHON_COMPETITOR_HOME` to a writable directory, then run migrations,
tests, and `doctor`. The fixture E2E is offline and makes no external writes.

## Plow deployment

The current public CLI owns the one-click deployment contract. From this
checkout, `scripts/deploy.ps1 -Image ghcr.io/account/joust:v1 -Line ln_xxx`
builds for `linux/amd64`, pushes the image, captures the resulting
`repository@sha256:<digest>`, and delegates the hosted request to
`plow-agents deploy`. The wrapper never sends a mutable tag to Plow. The
registry package must be public for Plow's anonymous pull.

For a fresh self-hosted run, set `AGENT_ID` and use
`scripts/deploy.ps1 -Local -Line ln_xxx`. The upstream local path validates
`.dockerignore`, mints `./plow-credentials`, and runs Compose. Existing Joust
installations with a configured credential path should use `scripts/preflight.py`
and `docker compose up --build -d`, because `deploy --local` intentionally owns
the default `./plow-credentials` path.

The hosted image is credential-free and tenant-free. Plow supplies
`PLOW_API_BASE`, the cloud identity, and any hosted authentication proxy inside
its provisioned runtime. Hosted registry pull and tenant lifecycle remain
Plow-side; `plow-agents agents` is the authoritative request/status check.
Verified status is separate from deployment and requires the Agent Index
eligibility flow.

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
