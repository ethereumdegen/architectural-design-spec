# ADR-0003 (starflask-monorepo): Each visual DSL ships both unit and screenshot-regression tests

- **Status:** Accepted
- **Date:** 2026-06-03
- **Scope:** starflask-monorepo (sf-frontend)
- **Deciders:** Andy

## Context

The product renders three DSLs into visual output — SlideScript (slides), DocScript (documents),
and InkScript (JSON-based reports). Unit tests over the parser catch *parsing* bugs but say nothing
about whether the result *looks right*; a layout regression (overlapping text, wrong spacing,
broken theme) passes every assertion while shipping a broken slide.

Evidence: `CLAUDE.md` documents both harnesses — Vitest unit tests (`slide-render.test.tsx`,
`doc-render.test.tsx`) and Playwright visual specs (`slide-visual.spec.ts`, `doc-visual.spec.ts`,
`inkscript-visual.spec.ts`) that emit PNGs to `sf-frontend/test-results/`.

## Decision

Every visual DSL will ship **two** test layers:

- **Unit tests (Vitest)** for parsing and the parse→render data path — fast, assertion-based.
- **Visual/screenshot tests (Playwright)** that render representative inputs and diff PNGs to catch
  rendering and layout regressions.

A new DSL feature is not "done" until both layers cover it. The two are complementary, not
alternatives.

## Consequences

- Rendering regressions are caught mechanically instead of in manual QA or by users.
- Visual baselines must be reviewed and updated intentionally when output legitimately changes.
- Playwright adds CI time and a browser dependency — accepted for a product whose output *is* the
  visual.

## Enforcement

- CI runs both Vitest and Playwright suites; a visual diff beyond threshold fails the build.
- Baseline PNG changes appear in the diff and require explicit review (you can *see* what changed).
- Convention: a PR adding DSL syntax without a corresponding visual spec is incomplete.
