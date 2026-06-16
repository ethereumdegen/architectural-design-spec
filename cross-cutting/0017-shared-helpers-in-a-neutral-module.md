# ADR-0017: Shared helpers live in a neutral module, never borrowed sideways between sibling sub-applications

- **Status:** Accepted
- **Date:** 2026-06-16
- **Scope:** cross-cutting
- **Deciders:** Andy

## Context

Our codebases grow into several **sibling sub-applications** within one crate/package — e.g. in
sprite-builder the `builds`, `codespaces`, and `docuspaces` domain modules all sit side by side
under `src/`. These peers are meant to be independent: each owns its own routes, storage, and
domain rules.

When a second sub-application needs a helper that already exists in the first, there is a tempting
shortcut: make the existing function `pub` and `use crate::codespaces::validate_rel_path` from
inside `docuspaces`. It compiles, it's one line, and it avoids duplication — so it feels right.

It isn't. That import is a **sideways dependency between peers**. `docuspaces` now depends on
`codespaces`' internals; `codespaces` can no longer be changed or deleted without breaking an
unrelated sibling; the dependency graph sprouts edges between modules that have nothing to do with
each other; and the helper keeps its original domain's vocabulary (a path validator that talks
about "the workspace" even when the caller is an S3 prefix). Repeated a few times, the sub-apps
quilt themselves together into spaghetti, and the boundaries that made them comprehensible
dissolve. This ADR exists because that shortcut was taken once and we are ruling it out.

## Decision

**A domain-agnostic helper needed by more than one sibling sub-application does not live inside
any one of them. It moves to a neutral shared location that the siblings depend on — never
sideways from peer to peer.**

Concretely:

- If sub-apps `A` and `B` both need a generic helper (e.g. `validate_rel_path`, `random_name`),
  that helper lives in a shared module/crate that sits **aside or above** the domains (e.g.
  `src/util.rs`, a `common` module, or a shared crate). Both `A` and `B` write
  `use crate::util::…`.
- **A sub-application must not import a helper from a sibling sub-application.** `B` never writes
  `use crate::A::…` for an incidental utility. (`docuspaces` must not reach into `codespaces`,
  and vice versa.)
- When a helper is promoted to the shared module, **generalize it** — strip the originating
  domain's names and error wording so it reads as neutral (e.g. "relative to the root", not
  "relative to the workspace").

This does **not** forbid depending on genuinely shared lower layers. Sub-apps may and should
depend downward on common foundations — `models`, `error`, `config`, a `storage` layer, the
shared `util` module. The dependency direction is the rule: **domain → shared, never
domain → peer domain.** Sharing flows through a common layer, not through a neighbor.

Alternatives rejected:

- **Make the helper `pub` on its current module and import across** — the shortcut this ADR
  forbids. Creates peer coupling and false ownership (the helper looks like it "belongs to"
  codespaces when it's generic).
- **Duplicate the helper in each sub-app** — avoids the coupling but invites drift: two copies
  diverge, and a bug fixed in one is missed in the other.

## Consequences

- The dependency graph between sibling sub-apps stays **acyclic and shallow** — peers are
  independent and can be reasoned about, refactored, or removed in isolation.
- Promoted helpers become **better helpers**: neutral names, neutral error messages, a documented
  single home.
- There is a small ongoing cost: a shared `util`/`common` layer to curate, and a moment of
  judgment on each helper — "is this actually shared, or does it belong to one domain?" Resist
  letting the shared module become a junk drawer; a helper that only one sub-app uses stays in
  that sub-app.
- Slightly more friction than the one-line `pub` shortcut, paid once at promotion time. Accepted.

## Enforcement

- **Module-boundary check (preferred):** a CI gate / architecture test asserting that no sibling
  domain module imports from another. For the Rust repos a grep gate is enough to start, e.g. fail
  if a domain module references `crate::<sibling_domain>::` for anything but a deliberately
  exported domain entry point — `rg 'use crate::(codespaces|docuspaces|builds)::' src/<other>.rs`
  should be empty. Encode the sibling list per repo.
- **Keep shared helpers `pub` only in the shared module**, so the only legal source of a generic
  helper is `crate::util` (a cross-domain `pub(crate)` helper is the smell this catches).
- **Code-review checklist item** as the backstop: any new `use crate::<peer>::` into a sibling
  sub-app must be justified or refactored into the shared layer.
