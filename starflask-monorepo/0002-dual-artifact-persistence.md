# ADR-0002 (starflask-monorepo): Artifacts use mutable working copies + an immutable audit trail

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** starflask-monorepo
- **Deciders:** Andy

## Context

Users generate an artifact (a slide deck, document, or report DSL) and then edit it in the UI. We
need two things that pull in opposite directions: a **mutable** working copy the editor can freely
change, and an **immutable** record of what was generated for audit and export history. Storing
only one loses either edit-ability or provenance.

Evidence: `architecture_considerations.md` describes a "Two-layer system: mutable
`session_artifacts` (working copy) + immutable `generations` (audit trail)." Exports read from the
in-memory parsed AST, so post-edit changes export correctly without mutating `generations`.

## Decision

Artifacts will be persisted in **two layers**:

- **`session_artifacts`** — the mutable working copy. The editor reads and writes this; session
  reload restores from it.
- **`generations`** — an immutable, append-only audit trail of what was generated. Never edited.
- **Exports** read from the **in-memory parsed AST** (the current working state), *not* from
  `generations`, so a user's edits are reflected in exports while the original generation remains
  preserved for history.

## Consequences

- Users edit freely without destroying the provenance record.
- Audit/history is trustworthy because `generations` is never mutated.
- Two stores to keep coherent; the working copy is the source of truth for the live editor and
  exports, `generations` for history.
- Slightly more storage — accepted.

## Enforcement

- `generations` is treated as append-only at the `db/` layer: provide insert + read functions, **no
  update**. The absence of an update function makes mutation impossible by construction.
- Export code paths take the parsed AST as input, not a `generations` row — a reviewer can verify
  export functions never query `generations`.
