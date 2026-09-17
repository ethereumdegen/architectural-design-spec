# ADR-0003 (tui): Terminal apps use the instrument-panel house style

- **Status:** Accepted
- **Date:** 2026-09-17
- **Scope:** tui (all terminal applications)
- **Deciders:** Andy

## Context

[Cross-cutting ADR-0018](../cross-cutting/0018-braille-spinner-standard-loading-indicator.md) gave the web frontends one recognizable loading aesthetic. Terminal apps deserve the same
treatment: `degen-radio` and `degen-tools` should look like two instruments from one workshop, not
two unrelated programs that happen to run in a terminal.

Both converged on the same shape without planning it: a status header, bordered panels for the
live data, a log at the bottom, and a single key bar on the last line. Writing it down turns a
coincidence into a template a new app can start from.

## Decision

We will draw terminal apps as an **instrument panel**: a fixed header, panels for state, a live
log, and a key bar.

- **Layout.** `Layout::vertical` with a fixed-height header, a flexible middle split horizontally
  into panels, a log region, and a one-line footer. Everything is sized in `Constraint`s so a
  resize redistributes rather than clips.
- **Panels.** `Block::bordered()` with `BorderType::Rounded`, a dim border colour, and a title
  padded with spaces (`" keys · 3 "`) in the accent colour, bold.
- **Palette.** A Tokyo-Night-family dark palette declared as `const Color::Rgb(...)` at the top of
  the UI module: dim text, body text, border, accent, plus green/yellow/red/cyan for state and one
  highlight (pink/purple) for the app's own mark. Never use bare `Color::Green` and friends — they
  are whatever the user's theme says, which makes the same app look different on two machines.
- **Header.** The app name in a reversed accent chip (`" ◆ DEGEN-TOOLS "`), a pulsing `●` with a
  status word, then version and uptime in dim text, then the one or two addresses that matter.
- **Log.** Newest first, columns `time · ok/err · what · duration · note`, with the status column
  carrying the only strong colour on the line.
- **Footer.** Reversed key chips with dim labels: `q quit`, `r reload`, `t token`, `↑↓ scroll`.
  Every interactive app shows its keys; nothing is discoverable otherwise.
- **Empty states** explain the next action rather than leaving a blank panel (the request log shows
  the exact command an agent uses to connect).

## Consequences

- New terminal apps start from a known skeleton and look like family immediately.
- Fixed RGB colours mean the app ignores the terminal's palette, which is the intent — at the cost
  of looking wrong on a light-background terminal. Accepted: these are dark-terminal tools.
- Panels and a footer cost vertical space, so the useful minimum size is roughly 80×24. Below that
  ratatui clips; nothing crashes.
- The style is a default, not a cage: a game or an art piece may abandon it deliberately.

## Enforcement

- Reference implementations: `degen-tools` `src/tui.rs`, `degen-radio` `src/radio_app/tui.rs`.
  Copy the palette block and the panel helper into a new app.
- `adr-checks.sh` (heuristic): flag `Color::(Red|Green|Blue|Yellow|Cyan|Magenta|White|Black)` in a
  crate that depends on `ratatui` — the house palette is RGB.
- Review: a screen with no key bar, or a panel drawn with square borders, in a non-game app.
