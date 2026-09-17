# ADR-0002 (tui): A TUI draws from a plain state struct, and its screens are asserted with TestBackend

- **Status:** Accepted
- **Date:** 2026-09-17
- **Scope:** tui (all terminal applications)
- **Deciders:** Andy

## Context

Terminal UIs have a reputation for being untestable, so they are usually shipped on the strength of
"I ran it and it looked right". That is exactly how a dashboard ends up printing a secret, or
losing a column on a narrow terminal, or showing stale data after a reload.

ratatui makes the opposite possible: rendering is a pure function from state to a cell buffer, and
`ratatui::backend::TestBackend` gives that buffer back as text. `degen-tools` uses this to assert
that its dashboard shows the credential names, the source of each value and the request log — and,
more importantly, that it does **not** contain the session token while the token is hidden. That
test runs in milliseconds in normal CI with no terminal attached.

## Decision

We will keep every drawable fact in a plain state struct, render from it with free functions, and
assert on rendered screens with `TestBackend`.

- One struct (`Dashboard`, `AppState`, …) holds everything the UI shows. Widgets never read a
  database, a file or the network during a draw; a `reload()`-style method refreshes the struct
  between frames.
- Drawing is `fn draw(frame: &mut Frame, state: &State)` plus one function per panel, each taking
  `(&mut Frame, Rect, &State)`. Panels take `&State`, not `&mut State`: a draw that mutates is a
  bug waiting for the next resize.
- Every terminal app has at least one test that builds a representative state, renders it through
  `Terminal::new(TestBackend::new(w, h))`, turns the buffer into a string and asserts on it:
  the facts that must appear, and the facts that must **not** appear (secrets, tokens, raw values).
- Test at a realistic small size (e.g. 110×30) so truncation shows up in CI rather than on a
  laptop at a conference.
- Gate an eyeball dump behind an env var (`SHOW_DASHBOARD=1 cargo test -- --nocapture`) so the same
  test doubles as the way a developer *looks* at the screen without launching the app.

## Consequences

- A TUI becomes as testable as a JSON API, and the "does it leak a secret?" question gets a
  regression test instead of a habit.
- State and rendering stay separable, so the same state can feed a second face later (a web view,
  a log line) without untangling widget code.
- The state struct duplicates data that lives elsewhere (config, packages, a queue). That is the
  accepted cost; the refresh point is explicit and therefore easy to reason about.
- Snapshot-style assertions are targeted, not golden-file diffs: assert on the handful of strings
  that carry meaning, or the test breaks every time a border character changes.

## Enforcement

- `adr-checks.sh` (heuristic): a crate that depends on `ratatui` but has no `TestBackend` reference
  anywhere in its tests is reported — a TUI with no rendered-screen test.
- Review: a panel function taking `&mut State`, or a widget body performing I/O (a file read, an
  HTTP call, a DB query) inside `draw`.
- A screen that renders a value it should only describe — a token, a key, a connection string —
  is caught here and nowhere else, so every such app asserts the raw value is *absent* from the
  buffer.
