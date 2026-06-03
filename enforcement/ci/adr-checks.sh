#!/usr/bin/env bash
# adr-checks.sh — heuristic gates for ADRs that aren't cleanly expressible as a compiler/lint rule.
# Run from a target repo root. Exits non-zero on a HARD violation; WARN findings never fail the build.
#
# These are deliberately simple greps: a noisy reminder beats silent drift. Tune the paths/patterns
# for the repo. Hard gates here back up the lint/cargo-deny gates for environments where those don't
# run; warn gates are pure reminders.
set -uo pipefail

fail=0
say()  { printf '%s\n' "$*"; }
hard() { say "❌ HARD  [$1] $2"; fail=1; }
warn() { say "⚠️  WARN  [$1] $2"; }

# Where source lives (Rust + TS). Adjust if your layout differs.
RS_GLOB='--include=*.rs'
SRC_DIRS=$(find . -type d -name src -not -path '*/target/*' -not -path '*/node_modules/*' 2>/dev/null)
[ -z "$SRC_DIRS" ] && SRC_DIRS=.

# Grep helper: matches in src, excluding tests/build/vendor. Prints file:line.
scan() { grep -rnE $RS_GLOB --exclude-dir=target --exclude-dir=node_modules "$1" $SRC_DIRS 2>/dev/null; }

say "── ADR conformance checks ─────────────────────────────────────────"

# ADR-0002 / ADR-0015 (HARD): SQL belongs only in db/ modules.
sql_outside_db=$(scan 'sqlx::query' | grep -vE '/db/|/db\.rs' || true)
if [ -n "$sql_outside_db" ]; then
  hard "ADR-0002" "sqlx::query* used outside a db/ module — move it into db/:"
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

# ADR-0011 (WARN): credential-shaped fields in structs (likely a request DTO carrying a token).
# Excludes the login DTO (password is legitimate there) and *token model* definitions.
creds=$(scan '^[[:space:]]*(pub[[:space:]]+)?(auth_token|access_token|session_token|api_key)[[:space:]]*:' \
        | grep -viE 'login|access_tokens_model|token_model|models/' || true)
if [ -n "$creds" ]; then
  warn "ADR-0011" "credential-shaped field — credentials belong in headers/cookies, not payloads:"
  printf '   %s\n' "$creds"
fi

# ADR-0016 (WARN): inline scope checks instead of a RequireScope extractor / the auth_scopes module.
inline_scope=$(scan '\.scopes\.contains' | grep -viE 'auth_scopes' || true)
if [ -n "$inline_scope" ]; then
  warn "ADR-0016" "inline scopes.contains(...) — use a RequireScope extractor:"
  printf '   %s\n' "$inline_scope"
fi

# ADR-0013 (WARN): stray prints (backs up the clippy gate for non-clippy environments).
prints=$(scan '\b(println!|eprintln!|dbg!)\(' || true)
if [ -n "$prints" ]; then
  warn "ADR-0013" "println!/dbg! in source — use the structured logger:"
  printf '   %s\n' "$prints"
fi

# CORS (WARN ONLY — no binding ADR yet, per decision): permissive CORS.
cors=$(scan 'allow_any_origin|AllowOrigin::any' || true)
if [ -n "$cors" ]; then
  warn "CORS" "permissive CORS detected — prefer an explicit allowlist (no binding ADR yet):"
  printf '   %s\n' "$cors"
fi

say "───────────────────────────────────────────────────────────────────"
if [ "$fail" -ne 0 ]; then
  say "ADR checks FAILED (hard violations above)."
  exit 1
fi
say "ADR checks passed (warnings, if any, are advisory)."
