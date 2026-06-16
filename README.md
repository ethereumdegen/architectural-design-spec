# Architectural Design Records (ADRs)

> The decision log for Starflask Digital's codebases. Read this **before** you write code.

This repository captures the **architecturally significant decisions** behind the major
projects in this org so that any engineer — human or agent — can absorb the *taste* of the
codebase in minutes and build on top of it without re-litigating settled questions.

An ADR records **one decision**: the *context* that forced it, the *decision* itself, its
*consequences*, and — critically for us — **how it is enforced** so it cannot silently rot.

## Why this exists

When a future agent starts working in one of these repos, it should not have to reverse-engineer
intent from the code. It reads the relevant ADRs and instantly understands:

- the conventions every file must follow,
- the failure modes we have already designed around,
- the patterns it must reuse instead of inventing new ones.

The goal is that **every decision a new contributor makes is already aligned** with how these
codebases are built. Where possible, the decision is enforced mechanically (a clippy lint, a
custom ESLint rule, a CI gate, the type system) so that non-conforming code **cannot be merged** —
not merely discouraged in review.

## How to use these (for agents and humans)

1. **Before starting work in a repo**, read its folder below *and* the `cross-cutting/` folder.
2. **Conform.** If your change conflicts with an Accepted ADR, you are almost certainly wrong —
   stop and reconsider. ADRs encode hard-won decisions.
3. **If a decision genuinely needs to change**, do not edit the Accepted ADR (they are immutable).
   Write a **new** ADR that *supersedes* it, and mark the old one `Superseded by ADR-XXXX`.
4. **When you make a new architecturally significant decision** (structure, security,
   dependencies, interfaces, tooling), capture it as a new ADR using `adr-template.md`.

## ADR lifecycle (per the [AWS ADR process](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html))

| Status | Meaning |
| --- | --- |
| `Proposed` | Drafted, under review. Not yet binding. |
| `Accepted` | Binding. Treat as immutable. Conform to it. |
| `Rejected` | Considered and declined (kept so we don't relitigate). |
| `Superseded` | Replaced by a newer ADR (linked). |

An accepted ADR is **immutable**. New insight → new ADR that supersedes the old one. ADRs focus on
*why* far more than *how*: understanding the reason makes the decision easy to adopt and hard to
accidentally overturn.

## Scope — what earns an ADR

Following Richards & Ford, capture a decision when it affects:

- **Structure** — patterns like monorepo layout, lib-vs-binary split, microservices
- **Non-functional requirements** — security, multi-tenancy, availability, fault tolerance
- **Dependencies** — coupling between components, choice of broker/DB/cache
- **Interfaces** — API shape, error contracts, published types
- **Construction** — libraries, frameworks, tooling, build/deploy, enforcement rules

## Enforcement

ADRs that can be machine-checked have starter configs in [`enforcement/`](enforcement/) — a
`clippy.toml`, `[workspace.lints]` blocks, a cargo-deny `deny.toml`, an ESLint flat-config snippet,
and a CI script (`adr-checks.sh`) for the rules a linter can't express. Copy them into a target repo
and wire them into CI. See [`enforcement/README.md`](enforcement/README.md) for the rule→ADR→mechanism
map and the two intentional carve-outs (boot may panic; tests may be loose). This is the part that
makes the rules "the linter won't let you commit it" rather than just documentation.

## Index

### Cross-cutting (the house style — applies to all repos)

| ADR | Decision |
| --- | --- |
| [0001](cross-cutting/0001-rust-library-plus-thin-binaries.md) | Rust services are a library crate with thin `server`/`worker`/`migrate` binaries |
| [0002](cross-cutting/0002-sqlx-compile-checked-sql-no-orm.md) | Data access uses SQLx (compile-checked SQL), never a general-purpose ORM |
| [0003](cross-cutting/0003-tenant-scoping-at-the-query-layer.md) | Owner/tenant scoping is an explicit parameter on every data-access function |
| [0004](cross-cutting/0004-authz-via-typed-request-extractors.md) | AuthN/AuthZ is expressed as typed request extractors, never inline role checks |
| [0005](cross-cutting/0005-config-from-environment-fail-fast.md) | Configuration is loaded from the environment at startup and fails fast |
| [0006](cross-cutting/0006-postgres-job-queue-skip-locked.md) | Background work runs on a Postgres queue with `FOR UPDATE SKIP LOCKED`, no broker |
| [0007](cross-cutting/0007-zustand-per-domain-stores.md) | Frontend state lives in per-domain Zustand stores, not Redux/Context |
| [0008](cross-cutting/0008-single-typed-api-client.md) | The frontend talks to the backend through one typed API client |
| [0009](cross-cutting/0009-centralized-json-error-contract.md) | ~~Errors map through one central type to a `{ "error": message }` JSON contract~~ (superseded by 0012) |
| [0010](cross-cutting/0010-no-panics-on-request-paths.md) | No panics on request paths; fail-fast belongs at boot, not in handlers |
| [0011](cross-cutting/0011-credentials-in-headers-not-payload.md) | Auth credentials travel in headers/cookies, never in request bodies or query strings |
| [0012](cross-cutting/0012-errors-map-to-correct-http-status.md) | Errors map to their correct HTTP status — never collapse to 500 (supersedes 0009) |
| [0013](cross-cutting/0013-structured-logging-never-log-secrets.md) | Use structured logging, never `println!`, and never log secrets |
| [0014](cross-cutting/0014-axum-standard-http-framework.md) | Axum is the standard HTTP framework for Rust services |
| [0015](cross-cutting/0015-sqlx-standard-db-client.md) | SQLx is the standard DB client — no raw-driver, hand-rolled models (extends 0002) |
| [0016](cross-cutting/0016-scope-based-authorization-from-roles.md) | Authorization is scope/capability-based, derived from roles at token-mint time |
| [0017](cross-cutting/0017-shared-helpers-in-a-neutral-module.md) | Shared helpers live in a neutral module, never borrowed sideways between sibling sub-applications |

### [starflask-monorepo](starflask-monorepo/) — multi-language generation platform

| ADR | Decision |
| --- | --- |
| [0001](starflask-monorepo/0001-stateless-backend-redis-shared-state.md) | Backend is stateless; all shared state lives in Redis |
| [0002](starflask-monorepo/0002-dual-artifact-persistence.md) | Artifacts use mutable working copies + an immutable audit trail |
| [0003](starflask-monorepo/0003-dsl-unit-plus-visual-tests.md) | Each visual DSL ships both unit and screenshot-regression tests |
| [0004](starflask-monorepo/0004-colocated-flags-over-allowlists.md) | Behavioral flags live on the entity, not in separate allowlists |
| [0005](starflask-monorepo/0005-redis-lua-concurrency-limits.md) | Concurrency is capped atomically via Redis Lua (global + per-user) |

### [metalcraft-agent](metalcraft-agent/) — Rust AI agent framework

| ADR | Decision |
| --- | --- |
| [0001](metalcraft-agent/0001-react-agent-via-rig.md) | Agents use the ReAct pattern over the `rig` SDK |
| [0002](metalcraft-agent/0002-versioned-seed-personas-skills.md) | Personas/skills/flows ship as version-gated, compiled-in seeds |
| [0003](metalcraft-agent/0003-integration-packs-layered-readonly.md) | Capabilities extend via read-only, layered integration packs |
| [0004](metalcraft-agent/0004-tool-approval-by-operation-kind.md) | Tool calls are gated by operation kind, not by tool name |
| [0005](metalcraft-agent/0005-declarative-http-tools-keystore.md) | HTTP tools are declarative JSON; secrets come from a key store |
| [0006](metalcraft-agent/0006-dual-diagnostics-otlp-tracing.md) | Every session emits local diagnostics + OTLP GenAI traces |
| [0007](metalcraft-agent/0007-step-guard-loop-detection.md) | A step guard halts error spirals and tool-call loops |

### [noblevida-web](noblevida-web/) — education web platform

| ADR | Decision |
| --- | --- |
| [0001](noblevida-web/0001-direct-to-s3-presigned-ledger.md) | Large uploads go browser→S3 via presigned URLs + a confirmation ledger |
| [0002](noblevida-web/0002-jwt-plus-scoped-impersonation.md) | Long-lived user JWTs + short-lived, separate impersonation tokens |
| [0003](noblevida-web/0003-redis-pubsub-websocket-chat.md) | Realtime chat fans out across instances via optional Redis pub/sub |
| [0004](noblevida-web/0004-pgtemp-integration-tests.md) | Integration tests run against a throwaway Postgres (`pgtemp`) |

---

*Template: [`adr-template.md`](adr-template.md). Decision log generated 2026-06-03 from the
state of `starflask-monorepo`, `metalcraft-agent`, and `noblevida-web`.*
