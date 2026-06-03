# ADR-0003 (noblevida-web): Realtime chat fans out across instances via optional Redis pub/sub

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** noblevida-web
- **Deciders:** Andy

## Context

Chat is delivered over WebSocket. With a single backend instance, an in-process hub is enough. But
the moment we run multiple instances (for availability or scale), two users connected to *different*
instances stop seeing each other's messages — each instance only knows its own sockets. We need
cross-instance fan-out, but we don't want to *require* Redis for small/local single-instance
deployments.

Evidence: `main.rs` builds `ChatHub::new(config.redis_url.as_deref())` and spawns
`spawn_chat_subscriber()`. `config.rs` makes `redis_url: Option<String>` — Redis is optional. The
`redis` crate is configured for Upstash over `rediss://` TLS. The frontend (`hooks/useChat.ts`)
connects to `/api/chat/ws` with exponential-backoff reconnect.

## Decision

Realtime chat will fan out across instances via **optional Redis pub/sub**:

- Messages are delivered to local sockets through a `ChatHub` **and** published to Redis; a
  subscriber on each instance relays incoming Redis messages to its local sockets.
- Redis is **optional** (`redis_url: Option<String>`): unset → single-instance mode (local hub
  only) still works for dev and small deployments; set → cross-instance delivery.
- Pub/sub is fire-and-forget — no durability; clients reconnect with exponential backoff and
  re-sync, so a dropped message isn't a correctness problem.

## Consequences

- Scales to multiple instances with **no sticky sessions** required at the load balancer.
- Local/dev runs need no Redis; production turns it on with one env var
  ([cross-cutting ADR-0005](../cross-cutting/0005-config-from-environment-fail-fast.md)).
- Pub/sub has no delivery guarantee — accepted; reconnect + re-sync covers gaps. Durable history,
  if needed, lives in the DB, not the bus.

## Enforcement

- The optional-Redis branch is encoded in the `Option<String>` config: the single-instance path is
  a first-class, tested mode, not an afterthought.
- Frontend reconnect/backoff is centralized in `useChat.ts`, so transient bus/socket gaps recover
  uniformly.
