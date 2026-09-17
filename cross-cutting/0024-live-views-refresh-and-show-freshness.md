# ADR-0024: A live view refreshes itself and shows that it is live

- **Status:** Accepted
- **Date:** 2026-09-17
- **Scope:** cross-cutting (all terminal applications)
- **Deciders:** Andy

## Context

The whole reason to leave a terminal app open is that it keeps telling you the truth. A screen that
only updates when you press a key is a screenshot with extra steps: the operator cannot tell
whether "3 keys, 0 failures" is current or from twenty minutes ago, and the natural reaction is to
mash `r` and distrust the display.

`degen-tools` shows keys read from a `.env` that the tool itself rewrites while running, so a stale
screen would actively mislead. It reloads its state every two seconds, pulses a status dot, and
prints uptime — three independent signals that what you are reading is now.

## Decision

We will make live views refresh on their own and render at least one piece of evidence that they
are live.

- **Refresh on a timer inside the draw loop** (a few seconds for cheap local state), not only on a
  keypress. The manual key stays as reassurance and for impatience.
- **Refresh must be cheap and non-blocking.** Anything slow (a network poll) belongs on its own
  thread or task, feeding the state struct through a channel; the draw loop never waits on I/O.
- **Show liveness explicitly.** At least one of: a pulsing/animated indicator tied to elapsed time,
  a visible uptime or clock, an event log with timestamps, or an explicit "updated Ns ago". A
  static screen with no such evidence is not acceptable for a live view.
- **Events are appended, not replaced.** A newest-first log of what the app did (with time, result
  and duration) is the primary trust-building element; keep a bounded ring (e.g. 500 entries) so
  memory is constant.
- **Never redraw destructively.** Immediate mode redraws the whole frame from state (ADR-0021), so
  a refresh never leaves half-updated rows.
- **Say what is unknown.** Where a value has not been read yet, follow ADR-0019: render the pending
  state, not a plausible-looking zero.

## Consequences

- The screen is trustworthy at a glance, which is the entire value of leaving it open on a second
  monitor during a deploy.
- A timer tick plus a 250 ms input poll means a background wakeup a few times a second; negligible
  for an operator tool, but this is why the pattern is for foreground apps and not for daemons.
- Refresh work must stay cheap, which pushes expensive state behind explicit actions — a healthy
  pressure.
- Animated elements must derive from elapsed time (`Instant::elapsed`), never from a frame counter,
  so they stay steady when the frame rate varies.

## Enforcement

- Reference implementation: `degen-tools` `src/tui.rs` (two-second `reload()`, pulsing status dot,
  uptime in the header, bounded request log).
- `adr-checks.sh` (heuristic): a crate depending on `ratatui` whose draw loop contains no
  `elapsed()` call is reported — no elapsed time means nothing on screen can be showing freshness.
- Review: a live view that only updates on a keypress, or one whose refresh performs I/O inside the
  draw call.
