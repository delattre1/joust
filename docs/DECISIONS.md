# Architectural decisions

## ADR-001 — Downstream Plow variant

Joust builds from the immutable official base tag and digest for
`plow-hermes-agent` commit `8710797b6409c77df560c6198407765d138ea617`.
Generic boot, chat, Latch, and Hermes behavior remain upstream.

## ADR-002 — Agent Index integration

Use the official `plow-pbc/agent-index-client` at reviewed commit
`87901f8b182a8a7c65ee3dd7267f8f835ee2a545`, verify SHA-256 at image build,
and invoke it from a supervised `s6` longrun. Joust implements no parallel
registration/reporting protocol.

## ADR-003 — Deterministic first slice

The architectural spine is initially deterministic and fixture-testable.
`LLMClient` is a provider-neutral protocol; later model-backed capabilities
must return Pydantic-validated structured output. State never mutates directly
from prose.

## ADR-004 — Devpost workflow does not apply

The AI Worth Using / Hermes event supplied by the user is not present in the
live Devpost managed-hackathon catalog. No Devpost event identity was invented
and no unrelated registration was performed. Competition updates supplied by
the organizer are recorded as project inputs until an official Agent Index
surface exposes an authoritative rules API.

## ADR-005 — Incomplete live rule sources block visibly

Real event pages often omit deadlines, prohibitions, or machine-readable rule
markup. Joust may infer conservative candidates from ordinary HTML, but it
must not invent missing hard rules. If the rules quality gate fails, the
  mission is persisted in `BLOCKED`, a `QUALITY_GATE_FAILED` event records the
  specific findings, and status exposes them without making downstream tasks
  ready. A missing deadline is recorded as explicitly unknown rather than
  silently treated as known.

## ADR-006 — Project target is separate from the agent repository

The repository that distributes Joust is not the project it builds for a
competition. Each mission may attach one `ProjectTarget` in `existing_repo`,
`new_repo`, or `local_only` mode. The target records the local path, optional
GitHub URL, branch policy, and explicit install/build/test commands.

The real build path uses a mission branch, records a `RepositorySnapshot`,
captures a `ChangeSet` and `BuildRun` records, and requires a passing build or
test command before the change set is considered validated. A dirty existing
workspace is refused rather than overwritten. GitHub push, pull-request,
deploy, and merge remain separate approval-gated actions; the local build loop
does not perform them implicitly.

## ADR-007 — Joust is the next architecture, not an implicit public rename

The user supplied a new Joust SDD whose available attachment ends at section
14. Sections 1–13 supersede the product direction where they are more specific:
the system is a persistent competition agent organized around control,
execution, and observation planes and a continuing compete loop.

The product/display name is Joust. The external Agent Index identifier remains
`galahad-hackathon`; it is a stable public ID, not a product or repository
name. A product rename, repository move, and Agent Index ID change are separate
decisions and must not be inferred from one another. Internal contracts are
extended compatibly first. The missing portion of the truncated SDD is not
inferred.

## ADR-008 — One model-backed mission intake

`mission joust-it` is the canonical operator intake. `mission create` remains
an alias to the same model-backed path for existing Plow skills. The older
deterministic `run_vertical_slice` and `complete_v0` helpers remain available
to offline tests only; production CLI commands do not route missions through
them. With no model provider, intake records a visible blocked mission and
creates no project.

## ADR-009 — Monitored cycle invocation; scheduler remains external

`mission compete-run` executes one lease-guarded, fingerprinted monitoring
attempt and ingests Agent Index metrics when `AGENT_ID` is provisioned. The
command is safe to invoke periodically, but this repository does not claim an
automatic schedule until the pinned Hermes base/runtime and a persisted job
configuration are verified together. Do not add a second scheduler service to
the variant without that compatibility check.
