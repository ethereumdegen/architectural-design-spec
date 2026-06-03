# ADR-0001 (noblevida-web): Large uploads go browser→S3 via presigned URLs + a confirmation ledger

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** noblevida-web
- **Deciders:** Andy

## Context

The platform accepts session recordings up to ~5 GB. Streaming those through our origin means
buffering multi-gigabyte bodies in server memory, tying up request workers, and paying for transit
twice. The natural fix — let the browser PUT directly to object storage (DigitalOcean Spaces) via a
presigned URL — introduces a new failure mode: if the browser crashes or the network drops after
the upload starts, an object lands in storage with **no corresponding `media` row**, orphaned and
billable forever.

Evidence: routes `/media/recording/presign` and `/media/recording/confirm` (`main.rs`);
`db/pending_uploads.rs` documents the ledger ("the browser PUTs recordings straight to Spaces
(bypassing our origin) … we record each presigned upload here and stamp it confirmed when the
browser confirms"); `services/orphan_sweep.rs` GCs unconfirmed uploads older than 24h every 6h. A
streaming fallback route allows up to 5 GB via `DefaultBodyLimit`.

## Decision

Large uploads will go **browser → S3 directly via presigned URLs**, tracked by a **`pending_uploads`
ledger** with explicit confirmation:

- The server issues a presigned PUT and records the intended upload in `pending_uploads`
  (unconfirmed).
- The browser uploads straight to Spaces, then calls a **confirm** endpoint that stamps the ledger
  row and creates the real `media` row.
- An **orphan sweeper** (background worker, [cross-cutting ADR-0006](../cross-cutting/0006-postgres-job-queue-skip-locked.md))
  deletes the storage object + ledger row for any upload that was presigned but never confirmed
  past an age cutoff (24h).
- A streaming-through-origin path exists only as a fallback.

## Consequences

- The origin never buffers gigabytes; request workers stay free; transit isn't doubled.
- Orphans are bounded: anything unconfirmed is reclaimed automatically, so storage can't grow
  without a matching `media` row.
- Two round-trips (presign, confirm) and a ledger to maintain — accepted as the cost of safe
  direct upload.

## Enforcement

- The ledger makes orphans *detectable*: "object exists, ledger unconfirmed" is the exact condition
  the sweeper queries — there is no path to a permanent orphan.
- Confirmation is required to create the `media` row, so an unconfirmed upload is never treated as a
  real asset.
