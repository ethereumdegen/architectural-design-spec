# ADR-0001 (starflask-monorepo): Backend is stateless; all shared state lives in Redis

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** starflask-monorepo
- **Deciders:** Andy

## Context

The backend must scale horizontally — multiple replicas behind a load balancer — to handle bursts
of generation traffic. Any per-process state (a worker registry, in-memory concurrency counters,
session caches) breaks the moment a second replica exists: replicas disagree, limits are enforced
per-process instead of globally, and a restart loses the state.

Evidence: `sf-backend/src/services/redis_store.rs` is documented as "Redis-backed shared state, so
the backend holds no per-process state and can run as multiple stateless replicas." Redis is
required at startup (`sf-backend/src/main.rs`) and the process fails fast if it is unreachable.

## Decision

The backend will hold **zero per-process mutable state**. All distributed state — worker registry,
concurrency counters, shared coordination — lives in **Redis**, accessed through a single
`RedisStore` on the app state.

- A Redis connection is **required at boot**; if Redis is unreachable the process refuses to start
  (consistent with [cross-cutting ADR-0005](../cross-cutting/0005-config-from-environment-fail-fast.md)).
- Any new shared state goes into `RedisStore`, not into struct fields or `static`s.
- Replicas are interchangeable; load balancing needs no sticky sessions.

## Consequences

- The backend scales out trivially; replicas can be added/removed freely.
- Redis becomes a hard dependency and a shared failure domain — accepted; it is also our queue's
  coordination layer and the concurrency limiter
  ([0005](0005-redis-lua-concurrency-limits.md)).
- State that "feels local" (caches) must be deliberately placed in Redis or recomputed.

## Enforcement

- Required-at-boot Redis connection makes a stateful misconfiguration crash immediately rather
  than degrade.
- Review/lint: `static mut`, module-level mutable singletons, and long-lived in-memory maps on app
  state are red flags — shared state belongs in `RedisStore`.
