# One-click Plow deployment architecture

Joust is a downstream Hermes variant. The deployment control plane belongs to
the official `plow-agents` CLI and Plow's hosted API; Joust owns the image
variant, its Compose contract, and the small operator-facing wrapper in
`scripts/deploy.ps1`.

## Ownership boundary

| Concern | Owner |
| --- | --- |
| Account login, line selection, credential mint/rotate/revoke | `plow-agents` |
| Image build, credential scan, registry push, digest extraction | `plow-agents` + Docker/registry |
| Hosted agent request and cloud lifecycle | `plow-agents` request + Plow provisioner |
| Joust persona, skills, mission package, Agent Index reporter | This repository |
| Local persistent Hermes home and Compose startup | This repository's `compose.yml` |

The wrapper never reads a Plow token, never constructs the private Plow API
contract, and never deploys a mutable image tag.

On Windows, the wrapper prefers the official CLI installed inside WSL because
the CLI's credential checks use POSIX file semantics. It falls back to a native
Windows CLI when WSL has no `plow-agents`; `-CliPath` is an explicit override.

## Hosted path

```text
scripts/deploy.ps1
  -> plow-agents image build IMAGE
  -> plow-agents image push IMAGE
  -> IMAGE@sha256:DIGEST
  -> plow-agents deploy IMAGE@sha256:DIGEST --line LINE
  -> Plow registry/provisioner
  -> hosted Joust container with injected identity/API environment
  -> plow-init resolves the tenant chat
```

The hosted path is credential-free inside the tenant VM. Plow supplies the
runtime API address and identity and may proxy authentication. A missing local
`PLOW_AGENT_TOKEN` is therefore not evidence that hosted Plow authentication is
broken. MCP/Latch configuration is a separate capability and is not required
for Plow Chat connectivity.

The wrapper requires a digest returned by `image push`; if the CLI does not
return one, it stops before requesting deployment. The official CLI also scans
the build context and refuses to build when `plow-credentials` is not excluded
by the applicable Docker ignore file.

## Fresh local path

```text
scripts/deploy.ps1 -Local
  -> plow-agents deploy --local
  -> validate Docker ignore excludes plow-credentials
  -> mint a line-scoped self-hosted credential
  -> docker compose up --build -d
  -> compose env_file loads the credential at runtime
```

The wrapper checks `AGENT_ID` before invoking the upstream local deploy so a
missing Agent Index identity cannot mint an agent that Compose will immediately
reject. If Compose fails, the upstream CLI preserves the credential and agent
for recovery; it does not silently revoke them.

An existing Joust installation may intentionally keep its credential at a
configured path such as `PLOW_CREDENTIALS` or `PLOW_CREDENTIALS_PATH`. The upstream `deploy --local`
command writes `./plow-credentials`, so that existing installation should use
the documented preflight and Compose path rather than creating a second agent.
When Compose is run from WSL, a Linux path such as
`/home/<user>/.config/joust/plow-credentials` is valid. When Compose is run
from PowerShell, use the equivalent `\\wsl.localhost\Ubuntu\home\<user>\...`
UNC path instead.

## Release invariants

- Build target is `linux/amd64`, matching hosted execution.
- Hosted requests use `repository@sha256:<digest>`, never a tag.
- `plow-credentials`, `.env`, account tokens, and GitHub sessions stay outside
  the image and Git history.
- `AGENT_ID` is explicit for local Compose and is provisioned by Plow when the
  hosted contract supplies it.
- Plow Chat, Agent Index reporting, and MCP/Latch are observed independently.
- A failed hosted handoff is reported as a Plow-side provisioning/registry
  issue, not misdiagnosed as a missing tenant credential.

## Current external boundary

The public CLI now contains the one-click build/push/deploy commands. The
actual hosted image pull, tenant provisioning, and runtime lifecycle remain
server-side Plow operations and require a successful Plow response. The Joust
repository can prepare and request that handoff, but cannot claim hosted health
until `plow-agents agents` reports the deployed status and the Plow Chat path is
verified.
