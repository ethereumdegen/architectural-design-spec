# ADR-0019: A control whose shape depends on an unfinished request renders the spinner, not a guess

- **Status:** Accepted
- **Date:** 2026-08-28
- **Scope:** cross-cutting (all frontends)
- **Deciders:** Andy

## Context

Our landing pages render immediately and resolve session state afterwards — `/` should not
cost a first-time visitor a round trip to `/whoami` before any pixels land. That part is
deliberate and stays.

What did not stay is what the page painted during that window. Session state was modelled as a
boolean, so "we have not asked yet" and "signed out" were the same value, and every control
derived from it rendered its signed-out shape by default. A signed-in visitor therefore landed
on a nav pill reading **Sign in with GitHub** — a claim the page had no basis for making — and
then watched it swap to **Dashboard** under their cursor a few hundred milliseconds later. Two
failures in one: the page asserted something untrue, and it moved a click target after the
reader had aimed at it. The first is the serious one. The default shape is not neutral; it is
the wrong answer for exactly the audience most likely to notice, because it is *their* button
that is wrong.

Reserving the layout box was not sufficient either. A held-open gap fixes the shove but still
leaves the reader with nothing to explain the delay, and the tempting fix — render the common
case and correct it later — is the lie again.

The reference implementation is `octaweave/frontend/src/routes/marketing/shell.tsx:78`
(`AuthState = 'unknown' | 'in' | 'out'`), consumed by
`octaweave/frontend/src/routes/marketing/SignIn.tsx` (`SignIn`, `SignInPill`) and rendered by
`octaweave/frontend/src/components/design/BrailleRain.tsx`.

## Decision

We will model any UI state derived from an in-flight request as **three states, not two**:
`unknown | <resolved A> | <resolved B>`. While the state is `unknown`, a control whose *shape*
depends on the answer renders the house loading indicator (ADR-0018's braille spinner) sized to
the footprint the resolved control will occupy — never the shape of one of the outcomes.

Concretely:

- The async state type names the pending case explicitly and it is the **initial** value
  (`const Auth = createContext<AuthState>('unknown')`). A boolean plus a separate `isLoading`
  flag is not equivalent — it permits the invalid pair, and the default branch renders anyway.
- Branch on all three cases at the point of render. A control that reads the same under both
  outcomes (static copy, a link that goes to the same place) may render immediately; only
  controls whose *destination, label, or affordance* differ must wait.
- The spinner occupies the resolved control's box (`h-10 w-40` for a nav pill, `h-12` for a
  CTA row), so the answer lands in place instead of shoving the page.
- The spinner element carries `role="status"` and a truthful `aria-label` describing what is
  pending ("Checking your session"), not a generic "Loading".
- Provide the state from a scope that covers every surface that consumes it. Scoping the auth
  provider to the landing route left the shared `Nav` — which also flies above `/docs` — stuck
  on `unknown`/signed-out forever (`shell.tsx:82`); it is provided at the app root instead.

Alternatives considered and rejected:

- **Render the signed-out shape, correct on arrival.** The status quo. Cheapest, and it is the
  defect: an assertion made without evidence, plus a moving click target.
- **Block the page until `/whoami` answers.** Truthful, but pays a round trip on every
  first-time visit to a marketing page — the exact cost we render-first to avoid.
- **Reserve the box with an empty placeholder.** Fixes layout shift only. The reader gets a
  hole with no account of it; a spinner says the true thing, which is that we do not know yet.
- **Optimistically render from a cached/last-known session.** Still a guess, and it is wrong in
  the case that matters most (signed out on a shared machine, or an expired session).

## Consequences

- Controls gated on a request get slightly more code: a three-way branch and a sized spinner
  instead of a ternary. That is the cost, and it is per-control, not per-app.
- The pending window is now visible rather than disguised. A slow `/whoami` reads as slow. This
  is desirable — it makes latency a bug we can see instead of one we paper over.
- Reduced-motion users get a still first frame rather than a 10fps flicker
  (`BrailleRain.tsx`, the `useReducedMotion` early return), so the pending state is still
  legible without the animation.
- No layout shift on resolution, because the spinner already holds the resolved footprint.
  Getting that footprint wrong reintroduces the shove, so the two sizes travel together.
- Applies beyond auth: feature flags, entitlement/premium gates, and permission-dependent
  actions have the same shape and the same failure mode.

## Enforcement

- Type system first: the async state is a union whose pending member cannot be skipped. Prefer
  `'unknown' | 'in' | 'out'` over `boolean | null` so a `switch`/ternary that omits the pending
  case is visible at the call site; an exhaustive `switch` with a `never` default makes it a
  compile error.
- Review: a control gated on fetched state that renders one of the resolved shapes before the
  fetch settles is rejected. So is a bare `{loading ? null : ...}` for a control that changes
  shape — null is the reserved-box variant this ADR rules out.
- Lint: a custom ESLint rule can flag `useState<boolean>(false)` paired with a fetch that
  assigns it, and `isLoading &&`/`?? false` collapses of a tri-state at a render site.
- The spinner itself is ADR-0018's; this ADR only says *when* it is mandatory.
