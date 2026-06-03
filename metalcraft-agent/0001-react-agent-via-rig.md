# ADR-0001 (metalcraft-agent): Agents use the ReAct pattern over the `rig` SDK

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

An agent needs a loop that reasons, calls tools, observes results, and repeats until done. We could
hand-roll this loop and a provider client, or build on an existing framework. Hand-rolling means
owning prompt formatting, tool-call parsing, retries, and provider quirks. We want a clear
think→act→observe structure with explicit interruption points (for approval, guards, hooks) and a
single LLM provider to start.

Evidence: `Cargo.toml` depends on `metalcraft = { version = "0.7.0", features = ["rig"] }` and
`rig = "0.37"`; `runtime.rs` uses `rig::providers::openai` and builds the agent via
`create_react_agent_with_hooks(model, registry, system_prompt, hook, llm_call_hook,
llm_response_hook)`. Default model `gpt-5.4`, with `gpt-5.4-mini`/`gpt-5.5` available.

## Decision

Agents will be built on the **ReAct (Reason+Act) pattern via the `metalcraft` framework over the
`rig` SDK**, against **OpenAI** as the initial provider:

- The agent graph is constructed with `create_react_agent_with_hooks`, giving explicit hook points
  for tool execution, LLM calls, and LLM responses — the seams where approval
  ([0004](0004-tool-approval-by-operation-kind.md)), the step guard
  ([0007](0007-step-guard-loop-detection.md)), and tracing
  ([0006](0006-dual-diagnostics-otlp-tracing.md)) attach.
- The model is configurable with a default (`gpt-5.4`) and an allowed list; it is not hard-coded at
  the call site.
- `rig` abstracts provider/tool-call mechanics; we do not hand-roll the loop or OpenAI plumbing.

## Consequences

- The think→act→observe loop and tool-call parsing come from the framework; we focus on tools,
  personas, and orchestration.
- Single provider for now; multi-provider would extend through `rig`'s abstraction (a future ADR).
- We are coupled to `metalcraft`/`rig` versions — accepted; the hook seams are worth it.

## Enforcement

- Agent construction is centralized in `runtime.rs`; other modules build agents through it, not by
  instantiating `rig` directly — so hooks/guards/tracing are never bypassed.
- The model default and allow-list live in one place; an unknown model is rejected rather than
  silently passed to the provider.
