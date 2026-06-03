# ADR-0005 (starflask-monorepo): Concurrency is capped atomically via Redis Lua (global + per-user)

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** starflask-monorepo
- **Deciders:** Andy

## Context

Generation work calls expensive external APIs (Anthropic, image/video providers). Two distinct
limits must hold simultaneously and correctly across a stateless, multi-replica backend
([0001](0001-stateless-backend-redis-shared-state.md)): a **global** cap (protect our overall
upstream rate limit and cost) and a **per-user** cap (stop one user monopolizing the queue).
Checking-then-incrementing a counter in application code races under concurrency and across
replicas, letting limits be exceeded.

Note: credits cap *cost*; concurrency caps *resources*. They are separate controls — credits do not
prevent a user from saturating the workers, and concurrency does not prevent overspending.

Evidence: `config.rs` exposes `max_concurrent_generations` and
`max_concurrent_generations_per_user`; `redis_store.rs` defines a `Slot` enum and an RAII
`SlotGuard` that releases on drop; Lua scripts (`acquire_slot.lua`, `release_slot.lua`,
`register_worker.lua`) perform the check-and-increment atomically.

## Decision

Concurrency limits will be enforced **atomically in Redis via Lua scripts**, at two levels (global
and per-user), with slots released through an **RAII guard**:

- Acquiring a slot runs a Lua script that checks both caps and increments in one atomic step — no
  check-then-set race across replicas.
- A `SlotGuard` releases the slot on `Drop`, so a panicking or early-returning handler cannot leak
  a slot.
- Limits are configuration values ([cross-cutting ADR-0005](../cross-cutting/0005-config-from-environment-fail-fast.md)),
  not constants.

## Consequences

- Limits hold exactly, even under bursty concurrent load across many replicas.
- Slot accounting self-heals: dropped guards always release.
- Logic lives partly in Lua, which must be maintained alongside the Rust caller — accepted for
  atomicity.

## Enforcement

- Atomicity is structural: the check and increment are one Redis round-trip (the Lua script), so a
  racing caller cannot exceed the cap.
- RAII (`SlotGuard: Drop`) makes leak-free release the default; you would have to work to leak a
  slot.
- Tests assert N+1 concurrent acquisitions block/queue when the cap is N.
