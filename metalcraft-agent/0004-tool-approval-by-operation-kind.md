# ADR-0004 (metalcraft-agent): Tool calls are gated by operation kind, not by tool name

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

An agent that can write files, run shell commands, and hit the network can do real damage if it
acts unsupervised. We need to gate dangerous actions behind human approval while keeping common,
safe reads fast — and the gate must keep working as new tools are added (including declarative HTTP
tools, [0005](0005-declarative-http-tools-keystore.md)). A per-tool-name allowlist rots: every new
tool needs a manual classification and a forgotten one defaults to the wrong thing.

Evidence: `approval.rs` defines `enum PermissionLevel { AutoApprove, RequiresApproval }` and
`enum OperationKind { ReadFile, WriteNewFile, OverwriteFile, EditFile, Execute, NetworkFetch,
SubAgent, … }`. `OperationKind::classify(tool_name, args)` maps a call to a kind (e.g. `write_file`
becomes `WriteNewFile` or `OverwriteFile` depending on whether the path exists). `default_permission()`
auto-approves reads and requires approval for destructive kinds. A scrollable diff preview is shown
for edits, and approval is TTY-gated (`--auto-approve` bypasses for non-interactive runs).

## Decision

Tool calls will be gated by **operation kind**, derived from the call, not by a per-tool allowlist:

- Each call is classified into an `OperationKind` from its name **and arguments** (so the same tool
  is "write new" vs "overwrite" based on whether the target exists).
- The **default permission follows the kind**: reads/list/search auto-approve; overwrite, edit,
  execute, network-fetch, sub-agent require approval. Meta-reads auto-approve; meta-writes require
  approval.
- Approval is **interactive and TTY-gated**, showing a scrollable diff for edits; `--auto-approve`
  (or non-interactive contexts) explicitly opts out.

A new tool inherits sane gating automatically by mapping to an existing kind — no per-tool decision
required.

## Consequences

- Safety is uniform and forgetting-resistant: new tools are gated by their kind, not by remembering
  to add them to a list.
- Common reads stay fast; only genuinely risky actions interrupt the user.
- A tool whose risk isn't captured by existing kinds requires extending the `OperationKind` enum —
  a deliberate, visible change.

## Enforcement

- Classification is centralized in `OperationKind::classify`; all tool execution flows through the
  approval hook ([0001](0001-react-agent-via-rig.md)), so a tool cannot run un-classified.
- Defaults are conservative: an unrecognized/destructive kind requires approval rather than failing
  open.
