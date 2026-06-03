# ADR-0003 (metalcraft-agent): Capabilities extend via read-only, layered integration packs

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

We want to distribute bundles of capability — a Discord pack (personas + message tools + formatting
skills), a Solarabase RAG pack — without forking the repo or having every user hand-assemble tools.
Those bundles must be overridable (a user should be able to shadow a pack's persona with their own)
but their contents must stay trustworthy (a user shouldn't accidentally mutate bundled files and
then receive a confusing "upgrade" later).

Evidence: `integration_packs.rs` defines packs as directories under
`<data>/integration_packs/<id>/` with `personas/`, `skills/`, `api_tools/`, `flow_templates/`, a
`pack.json` manifest (`id`, `name`, `version`, `requires_env`), and an enable-state file
`integration_packs.json`. `persona.rs::resolve_or_explain()` checks user-local files first, then
enabled packs — **user wins on collision**. `docs/architecture.md`: "Pack contents are read-only;
the Workshop API rejects writes to pack-owned items."

## Decision

Capabilities will extend through **integration packs** — versioned, optionally-enabled bundles —
resolved by a **layered, user-wins** lookup, with pack contents **read-only**:

- A pack is a directory with a manifest and subdirs for personas/skills/api_tools/flow_templates;
  `requires_env` declares the secrets it needs.
- Enable state lives in a single `integration_packs.json`; packs are off until enabled.
- Resolution order is **user-local first, then enabled packs** — a user file shadows a pack file of
  the same name without modifying the pack.
- Pack-owned items are **read-only**; the Workshop API rejects writes to them. To customize, you
  shadow with a user-local copy, you don't edit the pack.

## Consequences

- Teams distribute presets/integrations as drop-in bundles; no forking.
- Users override anything by shadowing, while the pristine pack remains for reference and upgrades.
- Versioned packs can ship breaking-change-aware updates.
- Two-layer resolution is a little more logic than a flat directory — accepted.

## Enforcement

- Read-only is enforced at the write boundary: the Workshop API refuses writes to pack-owned paths,
  so "edit a pack file" is structurally impossible through the API.
- Layering is centralized in `resolve_or_explain()`; all persona/skill/tool lookups go through it,
  so user-wins precedence is uniform.
