#!/usr/bin/env bash
# adr-checks.sh — heuristic gates for ADRs that aren't cleanly expressible as a compiler/lint rule.
# Run from a target repo root. Exits non-zero on a HARD violation; WARN findings never fail the build.
#
# These are deliberately simple greps: a noisy reminder beats silent drift. Tune the paths/patterns
# for the repo. Hard gates here back up the lint/cargo-deny gates for environments where those don't
# run; warn gates are pure reminders.
#
# Carve-outs (learned from auditing real repos):
#  - CLI/ops tooling under src/bin/** and **/scripts/** is EXEMPT from the SQL-in-db and no-println
#    gates: those programs read env at boot, print to stdout, and run direct SQL by design.
#  - The credential-field gate is struct-aware: it only flags *inbound* DTOs (structs named
#    *Input/*Request/*Payload/*Body/*Query/*Form/*Params/*Dto), never outbound API-response structs
#    (e.g. an OAuth `GoogleTokenResponse { access_token }`).
set -uo pipefail

fail=0
say()  { printf '%s\n' "$*"; }
hard() { say "❌ HARD  [$1] $2"; fail=1; }
warn() { say "⚠️  WARN  [$1] $2"; }

RS_GLOB='--include=*.rs'
SRC_DIRS=$(find . -type d -name src -not -path '*/target/*' -not -path '*/node_modules/*' 2>/dev/null)
[ -z "$SRC_DIRS" ] && SRC_DIRS=.

# Grep helper: matches in src, excluding tests/build/vendor. Prints file:line.
scan() { grep -rnE $RS_GLOB --exclude-dir=target --exclude-dir=node_modules "$1" $SRC_DIRS 2>/dev/null; }
# Drop CLI/ops tooling (bins + scripts dirs) — exempt from app-code gates.
no_tooling() { grep -vE '/(bin|scripts)/'; }

say "── ADR conformance checks ─────────────────────────────────────────"

# ADR-0002 / ADR-0015 (HARD): SQL belongs only in db/ modules — app code only (bins/scripts exempt).
sql_outside_db=$(scan 'sqlx::query' | no_tooling | grep -vE '/db/|/db\.rs' || true)
if [ -n "$sql_outside_db" ]; then
  hard "ADR-0002" "sqlx::query* used in app code outside a db/ module — move it into db/:"
  printf '   %s\n' "$sql_outside_db"
fi

# ADR-0015 (HARD): no raw driver / legacy wrapper imports (backs up deny.toml).
raw_driver=$(scan 'use (tokio_postgres|degen_sql)::' || true)
if [ -n "$raw_driver" ]; then
  hard "ADR-0015" "raw tokio-postgres / degen-sql import — use SQLx:"
  printf '   %s\n' "$raw_driver"
fi

# ADR-0014 (HARD): no actix-web (backs up deny.toml).
actix=$(scan 'use actix_web::' || true)
if [ -n "$actix" ]; then
  hard "ADR-0014" "actix-web import — standardize on Axum:"
  printf '   %s\n' "$actix"
fi

# ADR-0011 (WARN): credential-shaped field in an *inbound* DTO. Struct-aware: only flags fields
# inside request structs (Input/Request/Payload/Body/Query/Form/Params/Dto), never *Response/*Info,
# and skips CLI tooling. Avoids the "OAuth response struct" false positive.
rs_files=$(find $SRC_DIRS -name '*.rs' -not -path '*/target/*' 2>/dev/null | grep -vE '/(bin|scripts)/')
creds=""
if [ -n "$rs_files" ]; then
  creds=$(printf '%s\n' "$rs_files" | xargs awk '
    FNR==1 { inbound=0 }
    /struct[ \t]+[A-Za-z0-9_]+/ {
      for (i=1;i<=NF;i++) if ($i=="struct") { s=$(i+1); break }
      gsub(/[^A-Za-z0-9_].*/,"",s)
      inbound = (s ~ /(Input|Request|Payload|Body|Query|Form|Params|Dto)/) && (s !~ /(Response|Resp|Info|Output)/)
    }
    /(auth_token|access_token|session_token|api_key)[ \t]*:/ {
      # struct fields never contain "=" or "let" — excludes local bindings typed as a response
      if (inbound && $0 !~ /=/ && $0 !~ /(^|[ \t])let[ \t]/) printf "%s:%d:%s\n", FILENAME, FNR, $0
    }
  ' 2>/dev/null || true)
fi
if [ -n "$creds" ]; then
  warn "ADR-0011" "credential-shaped field in an inbound DTO — credentials belong in headers/cookies:"
  printf '   %s\n' "$creds"
fi

# ADR-0016 (WARN): inline scope checks instead of a RequireScope extractor / the auth_scopes module.
inline_scope=$(scan '\.scopes\.contains' | grep -viE 'auth_scopes' || true)
if [ -n "$inline_scope" ]; then
  warn "ADR-0016" "inline scopes.contains(...) — use a RequireScope extractor:"
  printf '   %s\n' "$inline_scope"
fi

# ADR-0013 (WARN): stray prints in app code (bins/scripts exempt — CLI output is their purpose).
prints=$(scan '\b(println!|eprintln!|dbg!)\(' | no_tooling || true)
if [ -n "$prints" ]; then
  warn "ADR-0013" "println!/dbg! in app code — use the structured logger:"
  printf '   %s\n' "$prints"
fi

# CORS (WARN ONLY — no binding ADR yet, per decision): permissive CORS.
cors=$(scan 'allow_any_origin|AllowOrigin::any' || true)
if [ -n "$cors" ]; then
  warn "CORS" "permissive CORS detected — prefer an explicit allowlist (no binding ADR yet):"
  printf '   %s\n' "$cors"
fi

# ── Terminal UI (ADR-0020..0024) — only meaningful in crates that draw a TUI ──────
tui_crates=$(grep -rln --include=Cargo.toml '^ratatui' . --exclude-dir=target --exclude-dir=node_modules 2>/dev/null || true)
if [ -n "$tui_crates" ]; then
  # ADR-0020 (WARN): crossterm as a second direct dependency — use the ratatui re-export.
  ct=$(printf '%s\n' "$tui_crates" | xargs grep -lE '^crossterm[ =]' 2>/dev/null || true)
  [ -n "$ct" ] && { warn "ADR-0020" "direct crossterm dependency alongside ratatui — use ratatui::crossterm:"; printf '   %s\n' "$ct"; }

  # ADR-0020 (WARN): terminal set up by hand loses ratatui::init's panic-restore hook.
  raw=$(scan 'enable_raw_mode\(|EnterAlternateScreen' || true)
  if [ -n "$raw" ] && ! scan 'ratatui::init\(' >/dev/null; then
    warn "ADR-0020" "raw mode entered without ratatui::init() — a panic will leave the terminal broken:"
    printf '   %s\n' "$raw"
  fi

  # ADR-0021 (WARN): a TUI with no rendered-screen test.
  scan 'TestBackend' >/dev/null || warn "ADR-0021" "crate draws a TUI but no test renders a screen with TestBackend"

  # ADR-0022 (WARN): named colours follow the user's theme; the house palette is RGB.
  named=$(scan 'Color::(Red|Green|Blue|Yellow|Cyan|Magenta|White|Black|Gray|Grey)\b' || true)
  [ -n "$named" ] && { warn "ADR-0022" "named ratatui colour — use the house Color::Rgb palette:"; printf '   %s\n' "$named"; }

  # ADR-0023 (WARN): keys must be advertised — a crate that matches KeyCode::Char needs a key bar.
  if scan "KeyCode::Char\\('" >/dev/null && ! scan 'fn draw_footer|footer|key bar|keybar' >/dev/null; then
    warn "ADR-0023" "keys are handled but nothing draws a footer/key bar — every key must be on screen"
  fi

  # ADR-0024 (WARN): nothing derived from elapsed time means nothing on screen shows freshness.
  scan 'elapsed\(\)' >/dev/null || warn "ADR-0024" "TUI never reads elapsed time — a live view must show that it is live"
fi

say "───────────────────────────────────────────────────────────────────"
if [ "$fail" -ne 0 ]; then
  say "ADR checks FAILED (hard violations above)."
  exit 1
fi
say "ADR checks passed (warnings, if any, are advisory)."
