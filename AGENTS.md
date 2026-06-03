# Agent instructions

This repository is a **decision log**, not application code. If you are an agent about to work on
`starflask-monorepo`, `metalcraft-agent`, or `noblevida-web`:

1. **Read [`README.md`](README.md)** and the relevant project folder + [`cross-cutting/`](cross-cutting/)
   **before writing code.** These ADRs encode the required conventions ("the taste") of those
   codebases.
2. **Conform to every Accepted ADR.** If your change conflicts with one, you are almost certainly
   wrong — stop and reconsider.
3. **Never edit an Accepted ADR** (they are immutable). To change a decision, add a new ADR that
   *supersedes* it, using [`adr-template.md`](adr-template.md), and mark the old one
   `Superseded by ADR-XXXX`.
4. **When you make a new architecturally significant decision** (structure, security, dependencies,
   interfaces, tooling), capture it as a new ADR — and prefer decisions you can **enforce
   mechanically** (a clippy lint, a custom ESLint rule, a CI gate, the type system) over decisions
   that rely on memory.
