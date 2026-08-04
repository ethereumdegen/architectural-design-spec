# ADR-0018: Braille-character spinner is the standard loading indicator

- **Status:** Accepted
- **Date:** 2026-08-03
- **Scope:** cross-cutting (all frontends)
- **Deciders:** Andy

## Context

Every app needs a "work in progress" indicator, and without a standard each frontend
reinvents one: a Tailwind `animate-spin` bordered circle here, a lucide `Loader` icon there,
an SVG somewhere else. The result is a visually inconsistent family of apps and duplicated,
slightly-different spinner code in each repo.

`solarabase-monorepo` established a distinctive house style: a text-based spinner that cycles
braille glyphs, driven by the `unicode-animations` npm package. It is a single small component
(`frontend/src/components/ui/BrailleSpinner.tsx`, ~40 lines) rendered as monospace text, and it
is already the canonical spinner there (`KbUsage`, `WikiPanel`, `FolderBrowser`, `QueryPanel`,
`Admin`). It reads as deliberately "terminal/hacker" rather than generic-web, which matches the
aesthetic wanted across the portfolio. This ADR promotes it from a solarabase detail to the
default for all apps.

## Decision

We will use a **braille-character text spinner** as the standard loading indicator across all
frontends, implemented as a small reusable component backed by the **`unicode-animations`**
package.

Reference implementation (`solarabase-monorepo/frontend/src/components/ui/BrailleSpinner.tsx`):

- Component named `BrailleSpinner`, living under the app's UI primitives (`components/ui/`).
- Frames come from `unicode-animations` (`import spinners from 'unicode-animations'`); the frame
  index advances on a `setInterval(..., spinner.interval)` cleaned up on unmount.
- Rendered as `font-mono` text (not an SVG/icon), so it inherits `currentColor` and font size.
- Props: `animation` (one of `rain | pulse | sparkle | orbit`, default `pulse`), `size`
  (`sm | md | lg`), optional `label`, optional `className`. Carries `aria-label="Loading"`.

Alternatives considered and rejected:

- **Tailwind `animate-spin` bordered circle** (as in `axoniac`'s `LoadingSpinner`) — fine, but
  generic; loses the house aesthetic. Acceptable only as an inline micro-spinner inside a button.
- **Icon-library spinners** (lucide `Loader`, react-spinners) — extra dependency weight and the
  same generic look.

## Consequences

- All apps share one recognizable loading aesthetic; copy `BrailleSpinner.tsx` into a new
  frontend and it fits instantly.
- Adds a small runtime dependency (`unicode-animations`) to each frontend that adopts it.
- Text-based means it themes for free via `currentColor` and font size — no fill/stroke plumbing.
- Existing generic spinners (e.g. `axoniac`'s `LoadingSpinner`, solarabase's inline
  `animate-spin` SVGs) are legacy; migrate them to `BrailleSpinner` opportunistically. A tiny
  inline `animate-spin` inside a button is a tolerated exception, not a second standard.
- New apps should scaffold `BrailleSpinner` as part of their base UI kit.

## Enforcement

- Convention: the shared `BrailleSpinner` component is the only full-screen/section loading
  indicator; new frontends copy the reference implementation.
- Review: a newly introduced spinner that is an SVG circle, a CSS `@keyframes spin`, or an
  icon-library loader used as the primary loading state is rejected in favor of `BrailleSpinner`.
- A custom ESLint rule can flag `animate-spin` usage outside a button/inline context and imports
  of `react-spinners` / spinner icons from icon libraries.
