# ADR-0023: Terminal apps are driven by single-key verbs that are always on screen

- **Status:** Accepted
- **Date:** 2026-09-17
- **Scope:** cross-cutting (all terminal applications)
- **Deciders:** Andy

## Context

A terminal app has no affordances. Nothing hints that `t` reveals a value or that `r` refreshes;
a user who does not know the keys can only quit — if they can work out how to quit. Apps that hide
their controls behind a `?` screen, or expect a typed command line, are learned once and forgotten
by the next session.

`degen-radio` and `degen-tools` both ended up with the same answer: a handful of one-key verbs,
printed on the last line at all times. The footer is never scrolled away, so the app teaches itself
while it runs.

## Decision

We will drive terminal apps with **single-key verbs**, listed in a permanent footer.

- **The universal keys, in every app:** `q` and `Esc` quit, `ctrl-c` quits, `↑`/`↓` (and `k`/`j`)
  move within the focused list, `Home`/`g` jumps to the top. `r` means refresh wherever refreshing
  means anything.
- **App verbs are one key, mnemonic, lower case** (`t` token, `f` favorite, `/` filter). Reserve
  capitals and modifiers for destructive or rare actions.
- **The footer shows them** as reversed key chips followed by a dim label, rendered from the same
  list the key handler matches on, so a key can never exist without being advertised.
- **Toggles change the screen, not a mode.** Pressing `t` flips a value between hidden and shown in
  place; it does not enter a sub-mode the user must escape.
- **Actions are immediate; a destructive action asks inline** with a one-line confirm in the footer
  region (`delete "show"? y/n`), never a modal dialog stack.
- **Mouse support is optional.** Everything must be reachable from the keyboard; nothing may
  *require* a mouse, because these apps run over SSH and in tmux.
- **No blocking prompts inside the live loop.** If input is genuinely needed, take it as an argument
  before the UI starts.

## Consequences

- The keyboard surface stays small enough to memorize, which is what makes these tools fast.
- The footer costs one line and the discipline of keeping it truthful — but since it is rendered
  from the key table, drift shows up as a missing chip rather than as a silent hidden feature.
- One-key verbs collide as an app grows: at that point the answer is a focused panel with its own
  verbs, not chords.
- Confirmations cannot be skipped by habit-typing an extra return, since they consume one key.

## Enforcement

- Reference implementations: `degen-tools` `src/tui.rs` (`draw_footer`), `degen-radio`
  `src/radio_app/tui.rs`.
- `adr-checks.sh` (heuristic): a `KeyCode::Char('…')` match arm whose character never appears in the
  file's footer/help strings is reported as an undocumented key.
- Review: an app with no footer, a `?`-only help screen, a typed command prompt inside the live
  loop, or a screen a keyboard cannot reach.
