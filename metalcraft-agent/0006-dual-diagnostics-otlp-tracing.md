# ADR-0006 (metalcraft-agent): Every session emits local diagnostics + OTLP GenAI traces

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

Debugging an agent run after the fact requires knowing what happened turn by turn: what the model
saw, which tools it called, what failed, when it compacted or switched persona/model. We need two
audiences served: a human poking at a local run, and an observability backend ingesting structured
traces (Phoenix, Langfuse, Braintrust). Logs alone serve neither well.

Evidence: `diagnostics.rs` writes a timestamped session dir with `session_info.json`,
`turn_NNN.json`, `llm_request_NNN.json`, and event files for persona/model switches, compaction,
and errors. `trace.rs` writes a parallel OTLP trace (`traces/<session_id>/otlp-trace.json`) with a
session root span, agent-turn spans, chat spans carrying `gen_ai.request.model` and token usage,
and execute_tool spans — following GenAI semantic conventions, sharing the same `<session_id>`.

## Decision

Every agent session will emit **two parallel, correlated observability streams**:

- **Local JSON diagnostics** under `sessions/<session_id>/` — per-turn files, LLM requests, and
  discrete event files (persona switch, model switch, compaction, error) for human inspection.
- **An OTLP trace** under `traces/<session_id>/` following **GenAI semantic conventions** — spans
  for the session, each turn, each LLM call (model + token usage), and each tool execution — ready
  to ingest into standard observability backends.
- Both share the **same `<session_id>`** and reuse the same timing stopwatches, so diagnostics and
  traces cross-reference exactly.

## Consequences

- A failed run is debuggable locally without any backend; the same run is analyzable at scale in an
  observability platform.
- GenAI-conventional spans mean no custom adapter per backend.
- Two writers to maintain and a little disk per session — accepted; sessions can be pruned.

## Enforcement

- Diagnostics and tracing attach at the framework hook points ([0001](0001-react-agent-via-rig.md)),
  so any agent built through `runtime.rs` is instrumented by default — you can't accidentally run an
  uninstrumented session.
- Span attributes follow the GenAI semantic-convention names (`gen_ai.request.model`, token usage),
  checked against the convention rather than ad hoc.
