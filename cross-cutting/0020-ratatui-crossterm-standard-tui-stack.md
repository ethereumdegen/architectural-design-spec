# ADR-0020: ratatui + crossterm is the standard TUI stack

- **Status:** Accepted
- **Date:** 2026-09-17
- **Scope:** cross-cutting (all terminal applications)
- **Deciders:** Andy

## Context

Several programs in the portfolio are terminal-first: `degen-radio` (an internet radio player),
`degen-tools` (a devops CLI whose `serve` mode shows a live dashboard), and the operator tools that
will follow. Without a house stack each one picks a different way to own the screen — raw ANSI
escapes, `dialoguer` prompt loops, `cursive`, `termion` — and none of the layout code, colour
handling or input handling transfers between them.

`degen-radio` settled on **ratatui** with the **crossterm** backend and the result reads well,
themes cleanly, and survives terminal resizing. `degen-tools` was built on the same stack and the
second implementation cost a fraction of the first, because the layout vocabulary
(`Layout::vertical`, `Constraint`, `Block`, `Table`, `Paragraph`) carried over unchanged. This ADR
makes that the default rather than a coincidence.

## Decision

We will build terminal UIs with **ratatui** on the **crossterm** backend, in an immediate-mode
loop owned by the application.

- Depend on `ratatui` (0.30 line) with `features = ["crossterm", "layout-cache"]` and
  `default-features = false`. Reach crossterm through the `ratatui::crossterm` re-export rather
  than a second direct dependency, so the two versions cannot drift apart.
- Enter and leave the alternate screen with `ratatui::init()` / `ratatui::restore()`. They install
  the panic hook that restores the terminal, so a crash never leaves the user's shell in raw mode.
- The loop is: drain application events, redraw the whole frame, then
  `event::poll(Duration::from_millis(250))` for input. Redrawing everything each pass is the point
  of immediate mode — no retained widget tree to keep in sync.
- Keep the UI thread synchronous. Work that blocks (HTTP, a server, a player) runs elsewhere and
  reaches the UI over a channel; `degen-tools` runs its API server on a Tokio runtime and sends
  `LogEntry` values to the drawing loop through an `std::sync::mpsc` channel.
- Always offer `q`, `Esc` and `ctrl-c` as exits.

Alternatives considered and rejected:

- **`cursive`** — retained-mode and callback-driven; a different mental model from the rest of our
  Rust, and harder to drive from a plain state struct (see ADR-0021).
- **Raw crossterm / termion drawing** — every app re-invents layout and wrapping.
- **Prompt libraries (`dialoguer`, `inquire`)** — fine for a one-shot question, but they own the
  flow and cannot show a live view. Acceptable inside a wizard, never as the app's main screen.

## Consequences

- Terminal apps share a layout vocabulary; code and components move between them by copy-paste.
- Immediate mode means every frame is a pure function of state, which is what makes ADR-0021's
  snapshot tests possible.
- A 250 ms poll costs a wakeup four times a second; for a dashboard this is invisible and it keeps
  animation (a pulsing indicator, a clock) honest without a second timer.
- Blocking work must be pushed off the UI thread deliberately. That is a real constraint and the
  reason the channel is part of the pattern rather than an afterthought.
- We inherit ratatui's release cadence; pin the minor version in the workspace and upgrade on
  purpose, since 0.x releases do move APIs.

## Enforcement

- `deny.toml`: ban `cursive`, `termion`, `termwiz` and `ncurses` so a second TUI stack cannot enter
  the dependency graph.
- `adr-checks.sh` (heuristic): flag a direct `crossterm` dependency in a crate that already depends
  on `ratatui` — use the re-export.
- `adr-checks.sh` (heuristic): flag `enable_raw_mode(`/`EnterAlternateScreen` used without
  `ratatui::init`, which is how the panic-hook restore gets lost.
- Review: a terminal app whose main screen is a prompt loop rather than a drawn frame.
