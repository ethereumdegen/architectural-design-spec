# ADR-0002 (noblevida-web): Long-lived user JWTs + short-lived, separate impersonation tokens

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** noblevida-web
- **Deciders:** Andy

## Context

Admins need to "view as" a user to debug support issues. The dangerous, easy way is to overload the
normal session — flip a field on the admin's own token. That conflates two very different
authorities (the admin's, and the impersonated user's), and a long-lived impersonation is a large
blast radius if the token leaks. We want impersonation to be **separate, explicit, and short**.

Evidence: `middleware/jwt.rs` mints the main token with a **7-day** expiry and the impersonation
token with a **1-hour** expiry, stored in a distinct `nv_impersonate` cookie.
`middleware/auth.rs` swaps the effective user id only when an admin presents a valid impersonation
cookie, setting `is_impersonating = true`. Logout clears **both** `nv_token` and `nv_impersonate`.
Role checks re-derive the role from the DB rather than trusting stale claims
([cross-cutting ADR-0004](../cross-cutting/0004-authz-via-typed-request-extractors.md)).

## Decision

Authentication will use **long-lived user JWTs** plus a **separate, short-lived impersonation
token**:

- Normal sessions: a JWT with a **7-day** expiry in `nv_token`.
- Impersonation: a **distinct** JWT with a **1-hour** expiry in `nv_impersonate`. It does not
  replace the admin's session; the auth extractor swaps the effective user and flags
  `is_impersonating`.
- Logout clears both cookies (`Max-Age=0`).
- Authorization extractors re-fetch role/identity rather than trusting token claims, so a revoked
  admin can't keep acting via a stale token.

## Consequences

- Impersonation has a small, time-boxed blast radius (1h) and is always distinguishable
  (`is_impersonating`).
- The two authorities never merge into one token.
- Two cookies and two token lifetimes to manage — accepted for the safety boundary.

## Enforcement

- The lifetimes are set in one place (`jwt.rs`); the 1h cap is structural, not a runtime check.
- `is_impersonating` flows through the typed extractor, so handlers/audit can act on it without
  re-deriving impersonation state.
