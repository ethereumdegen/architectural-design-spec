# ADR-0004 (starflask-monorepo): Behavioral flags live on the entity, not in separate allowlists

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** starflask-monorepo (applies as a general taste rule)
- **Deciders:** Andy

## Context

When an entity has a behavioral flag (e.g. "this media item is preserved and exempt from the
retention sweeper"), there are two ways to store it: a column on the entity itself, or a separate
set/list/table elsewhere (`preserved_media_ids`). The separate-list approach scatters related data,
so a single conceptual change requires editing two places ("shotgun surgery"), and the list can
drift out of sync with the entities it references.

Evidence: `CLAUDE.md` states the rule explicitly — "Colocated flags over separate allowlists: When
entities have behavioral flags, put the flag on the entity definition itself — not in a separate
set/list elsewhere." The `media_items` table carries a `preserve` flag on the row rather than a
`preserved_media_ids` table.

## Decision

Behavioral flags will be stored **on the entity definition itself** (a column on the row), not in a
separate allowlist, set, or side table.

- New per-entity flags are columns on the entity, defaulted appropriately in a migration.
- Queries, inserts, deletes, and the entity's lifecycle all touch one row.
- We avoid side tables whose only purpose is to mark a subset of another table's rows.

## Consequences

- Related data stays together; one row, one place to read/update the flag.
- No drift between an allowlist and the entities it references.
- Cascade/delete semantics are automatic — removing the entity removes its flags.
- Wide tables if flags proliferate — accepted; preferable to fragmentation.

## Enforcement

- Schema review: a migration that introduces a `*_ids` allowlist table for a boolean property is
  challenged in favor of a column on the entity.
- This is a documented coding guideline in `CLAUDE.md`, so agents working the repo inherit it.
