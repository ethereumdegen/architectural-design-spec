# Enforcement starters

These are **copy-into-your-repo** starter configs that turn the ADRs from prose into gates a commit
can fail. They are written for the house stack (Rust + Axum + SQLx backend; Vite + React + strict TS
frontend). Drop them into a target repo, tune paths, and wire `adr-checks.sh` into CI.

> An ADR worth recording is usually worth enforcing. Where a rule can't be a hard compiler/lint gate
> (e.g. "scope comes from the extractor"), we fall back to a **heuristic** grep check that *warns* —
> better a noisy reminder than nothing. Each gate below is labeled **hard** or **heuristic**.

## What's here

| File | Wire it in by |
| --- | --- |
| `rust/clippy.toml` | placing at the workspace root (Clippy reads it automatically) |
| `rust/workspace-lints.toml` | pasting its blocks into the workspace `Cargo.toml`, then adding `[lints]\nworkspace = true` to each crate |
| `rust/deny.toml` | installing `cargo-deny` and running `cargo deny check bans` in CI |
| `ts/eslint.config.mjs` | merging its rules into the frontend's flat ESLint config |
| `ci/adr-checks.sh` | running it in CI from the repo root (exits non-zero on a hard violation) |

## Rule → ADR → mechanism

| ADR | Rule | Mechanism | Type |
| --- | --- | --- | --- |
| [0002](../cross-cutting/0002-sqlx-compile-checked-sql-no-orm.md) | No general-purpose ORM | `deny.toml` bans `diesel`/`sea-orm`/`rbatis` | **hard** |
| [0002](../cross-cutting/0002-sqlx-compile-checked-sql-no-orm.md) | SQL lives only in `db/` | `adr-checks.sh`: `sqlx::query*` outside `**/db/**` | heuristic |
| [0003](../cross-cutting/0003-tenant-scoping-at-the-query-layer.md) | Unscoped queries must be named `*_admin`/`*_unscoped` | `adr-checks.sh` reminder | heuristic |
| [0005](../cross-cutting/0005-config-from-environment-fail-fast.md) / [0010](../cross-cutting/0010-no-panics-on-request-paths.md) | Read env only at boot | `clippy.toml` `disallowed-methods` on `std::env::var*` (allow in config module) | **hard** |
| [0007](../cross-cutting/0007-zustand-per-domain-stores.md) | No Redux; no Context-as-state | ESLint `no-restricted-imports` (redux) + `no-restricted-syntax` (createContext, warn) | **hard** / heuristic |
| [0008](../cross-cutting/0008-single-typed-api-client.md) | Talk to backend only via `api/` | ESLint `no-restricted-globals` (`fetch`) + ban `axios`, off inside `src/api/**` | **hard** |
| [0010](../cross-cutting/0010-no-panics-on-request-paths.md) | No `unwrap`/`expect`/`panic` on request paths | `workspace-lints` deny `unwrap_used`/`expect_used`/`panic`/`unreachable`/`todo` (allowed in tests + boot) | **hard** |
| [0011](../cross-cutting/0011-credentials-in-headers-not-payload.md) | No credentials in request DTOs | `adr-checks.sh`: token-ish field names in structs | heuristic |
| [0013](../cross-cutting/0013-structured-logging-never-log-secrets.md) | No `println!`/`dbg!`; structured logs | `workspace-lints` deny `print_stdout`/`print_stderr`/`dbg_macro` (allowed in tests) | **hard** |
| [0013](../cross-cutting/0013-structured-logging-never-log-secrets.md) | Never log secrets | review (no reliable lint) | review |
| [0014](../cross-cutting/0014-axum-standard-http-framework.md) | Axum, not actix-web | `deny.toml` bans `actix-web`/`actix-*` | **hard** |
| [0015](../cross-cutting/0015-sqlx-standard-db-client.md) | SQLx, not raw driver | `deny.toml` bans `tokio-postgres`/`degen-sql`/`postgres`; CI `cargo sqlx prepare --check` | **hard** |
| [0016](../cross-cutting/0016-scope-based-authorization-from-roles.md) | Capabilities via `RequireScope`, mapping in one module | review + `adr-checks.sh` reminder for inline `scopes.contains` | heuristic |

> **CORS** (the rejected-for-now rule): `adr-checks.sh` *warns* on `allow_any_origin` but never
> fails the build, per the decision to hold off on a binding CORS ADR.

## The two intentional carve-outs

1. **Boot may panic.** `unwrap`/`expect` and `std::env::var` are legitimate in the config module and
   `main.rs` startup. Scope the allow narrowly:
   ```rust
   // src/config.rs  (the one place env is read, at boot)
   #![allow(clippy::disallowed_methods, clippy::unwrap_used, clippy::expect_used)]
   ```
2. **Tests may be loose.** `clippy.toml` sets `allow-unwrap-in-tests`, `allow-expect-in-tests`,
   `allow-dbg-in-tests`, `allow-print-in-tests` so test code isn't punished by the request-path rules.

## Suggested CI shape

```yaml
# Rust
- run: cargo clippy --all-targets -- -D warnings   # honors clippy.toml + [workspace.lints]
- run: cargo deny check bans
- run: cargo sqlx prepare --check --workspace       # ADR-0015 offline cache not stale
# Frontend
- run: npm run lint
- run: npx tsc --noEmit                              # ADR-0008 strict TS
# Cross-cutting heuristics
- run: ./enforcement/ci/adr-checks.sh
```
