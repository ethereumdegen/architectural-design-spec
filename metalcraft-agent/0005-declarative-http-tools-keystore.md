# ADR-0005 (metalcraft-agent): HTTP tools are declarative JSON; secrets come from a key store

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** metalcraft-agent
- **Deciders:** Andy

## Context

Integrating a new HTTP API as an agent tool should not require writing Rust and recompiling — a
DevOps user should be able to add one by configuration. At the same time, tool configs are shared
and shippable (inside packs, [0003](0003-integration-packs-layered-readonly.md)), so they must
**never** contain credentials.

Evidence: `tools/http_api.rs` defines `HttpApiToolConfig` (name, description, method, url, headers,
parameters, body mapping/template/defaults, nested `param_paths`, `poll`, `multipart`) loaded from
JSON via `from_config_file`/`try_load` (local `api_tools/` then enabled packs). `expand_env(s)`
substitutes `$NAME` from the key store or environment; `expand_url(args)` fills `{param}`
placeholders and strips unset optional params. `key_store.rs` stores secrets as JSON at
`<data>/keys.json`, with `lookup(name)` checking the key store then the environment.

## Decision

HTTP-backed tools will be **declarative JSON configs**, with secrets injected at call time from a
**key store**, never embedded in the config:

- A tool is a JSON file describing method, URL, params, body mapping, and optional poll/multipart
  behavior; it is loaded from local `api_tools/` or an enabled pack. No recompile to add a tool.
- Configs contain **`$NAME` placeholders only**; actual secrets are resolved at runtime via
  `lookup(name)` → key store, then environment as fallback.
- URL/body `{param}` placeholders are expanded from tool args; unset optional params are dropped.
- Tools marked `"poll": true` are treated as status-polling and are exempt from tight loop
  detection ([0007](0007-step-guard-loop-detection.md)).

## Consequences

- Non-Rust users add integrations by writing JSON; packs ship integrations safely.
- Credentials stay out of shippable/committed config — a leaked config leaks no secrets.
- Key-store-then-env fallback supports both managed secrets and legacy env-var setups.
- The config schema is one more thing to maintain as new HTTP shapes appear — accepted.

## Enforcement

- Separation is structural: configs hold `$NAME` placeholders; the *only* path to a real secret is
  `lookup()` at call time, so a credential physically cannot live in a tool JSON.
- Convention/review: a literal token in an `api_tools/*.json` is rejected — use a `$NAME` + key
  store entry.
