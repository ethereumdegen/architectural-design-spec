# ADR-0007 (metalcraft-agent): A step guard halts error spirals and tool-call loops

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

Autonomous agents fail in two expensive ways: they spiral (every tool call errors, but the model
keeps trying), or they loop (call the same tool with the same args over and over). Both burn tokens
and wall-clock with no progress, and an unattended daemon run ([flows](../README.md)) can do this
indefinitely. We need a circuit breaker that distinguishes a genuine retry-loop from legitimate
status polling (which *is* the same call repeated, by design).

Evidence: `guard.rs` defines `GuardConfig { max_consecutive_errors: 3, max_identical_repeats: 4,
max_poll_repeats: 60, poll_tools, verbose }`. `build_agent_guard()` returns a `StepGuard` closure
run after each turn; `GuardTracker::check()` inspects new tool calls/results, tracking consecutive
errors and recent-call hashes for dedup. Poll tools (declared via `HttpApiTool::poll_tool_names()`,
[0005](0005-declarative-http-tools-keystore.md)) get the higher `max_poll_repeats` threshold.

## Decision

Every agent run will be wrapped in a **step guard** that halts on:

- **Error spirals** — ≥ `max_consecutive_errors` (3) consecutive all-error tool turns.
- **Tight loops** — the same tool call repeated ≥ `max_identical_repeats` (4) times (detected by
  hashing call name + args).
- **Runaway polling** — poll-marked tools are *exempt* from the tight-loop limit and instead
  bounded by a much higher `max_poll_repeats` (60), so legitimate async-job polling isn't killed
  while still being capped.

Thresholds are configurable; verbose mode logs tool calls/results to stderr for debugging.

## Consequences

- Unattended runs (flows, the daemon) can't burn unbounded tokens on a spiral or loop.
- Legitimate polling keeps working because poll tools have their own, higher ceiling.
- Thresholds are heuristics — a pathological-but-real workload could trip them; tunable per run.

## Enforcement

- The guard is installed as a post-turn hook in `runtime.rs` ([0001](0001-react-agent-via-rig.md)),
  so every agent built through the runtime is protected — opting out requires deliberately changing
  construction.
- Poll-tool exemption is wired from the tool layer (`poll: true`), so the guard and the HTTP-tool
  config stay in sync automatically.
