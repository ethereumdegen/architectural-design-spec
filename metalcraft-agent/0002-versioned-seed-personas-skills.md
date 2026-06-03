# ADR-0002 (metalcraft-agent): Personas/skills/flows ship as version-gated, compiled-in seeds

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

A fresh install must be useful immediately, with no network fetch — it needs default personas,
skills, and flows out of the box. But users also customize those files locally. So we have a
tension: ship improvements to the built-in defaults (e.g. a tuned persona system prompt) *without*
clobbering a user's own edits.

Evidence: `seed.rs` embeds the `seed/` directory into the binary via `include_dir!`. On startup,
`ensure_defaults()` calls `write_versioned_seeds()` for personas and `write_seeds()` for
skills/flows. Personas carry a `version`; `write_versioned_seeds()` overwrites the installed copy
only when the bundled version is higher. Skills/flows are write-if-missing and never overwritten.

## Decision

Defaults will be **compiled into the binary** (`include_dir!`) and written to the data dir at
startup, with **two upgrade policies**:

- **Personas are versioned and force-upgraded**: if a bundled persona's `version` exceeds the
  installed copy's, the installed file is overwritten. This lets us push prompt improvements
  automatically.
- **Skills and flows are write-if-missing**: written once when absent, **never** overwritten, so
  user edits are preserved.
- Seeds ship inside the binary, so first run needs no external download and the Docker image is
  self-contained (the `seed/` dir is COPY'd in the Dockerfile for completeness).

## Consequences

- New installs work instantly; maintainers can ship persona improvements that roll out on next run.
- User-authored skills/flows are safe from being clobbered.
- A user who edits a *bundled* persona may have it overwritten on version bump — accepted and
  intentional; local overrides belong in a pack or a renamed persona
  ([0003](0003-integration-packs-layered-readonly.md)).

## Enforcement

- The two write paths (`write_versioned_seeds` vs `write_seeds`) encode the policy in code, not in
  documentation — the upgrade behavior is determined by which function a seed type goes through.
- Version comparison is semantic (major.minor.patch); a malformed/absent version is treated as
  "upgrade", keeping installs current.
