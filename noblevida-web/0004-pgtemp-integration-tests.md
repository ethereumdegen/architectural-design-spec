# ADR-0004 (noblevida-web): Integration tests run against a throwaway Postgres (`pgtemp`)

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** noblevida-web
- **Deciders:** Andy

## Context

Integration tests that hit a shared/remote database are flaky and dangerous: tests interfere with
each other, require cleanup, and can corrupt real data. Mocking the database instead would test our
mocks, not our SQL — unacceptable given we hand-write SQL with SQLx
([cross-cutting ADR-0002](../cross-cutting/0002-sqlx-compile-checked-sql-no-orm.md)). We want each
test run against a **real, pristine, isolated** Postgres, with no Docker requirement for local dev.

Evidence: `nv-backend/tests/common/mod.rs` — "Default mode spins up a throwaway local Postgres via
`pgtemp` (no Docker) and runs the migrations into it, so tests never touch a shared/remote database
and need no cleanup." `Cargo.toml` dev-deps include `pgtemp = "0.7"` (requires `initdb`/`pg_ctl` on
PATH). It falls back to `TEST_DATABASE_URL` when set (CI mode).

## Decision

Integration tests will run against a **throwaway local Postgres via `pgtemp`**, migrated fresh, with
an external-pool fallback for CI:

- Default: `pgtemp` spins up a fresh Postgres (no Docker), migrations are applied, the test gets a
  pristine DB, and nothing needs cleanup — the instance is discarded.
- Tests exercise **real SQL** against a real engine, so SQLx queries are genuinely verified.
- CI (or any env that prefers a managed DB) sets `TEST_DATABASE_URL` to point at an external pool
  instead of spinning up binaries.

## Consequences

- Tests are isolated and reproducible; no shared fixtures, no cleanup, no cross-test interference.
- Our actual SQL is tested, not a mock of it.
- `pgtemp` requires Postgres server binaries on PATH locally and in CI — accepted; documented in
  `Cargo.toml`.

## Enforcement

- The test harness (`tests/common/mod.rs`) is the single entry point for a DB pool (`test_db()`),
  so a test cannot accidentally point at a real database — it gets a throwaway or the explicit
  `TEST_DATABASE_URL`.
- Migrations run into the throwaway instance, so tests automatically exercise the current schema.
