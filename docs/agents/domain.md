# Domain Docs

This repo uses a single-context layout: `CONTEXT.md` at the root and ADRs under `docs/adr/`.

## Before exploring

Read the root `CONTEXT.md` and any `docs/adr/` decisions relevant to the work. If they do not exist yet, proceed silently. The domain-modeling skills create them when terms or decisions are resolved.

## Layout

/
├── CONTEXT.md
├── docs/adr/
└── src/

## Vocabulary

Use terms defined in the `CONTEXT.md` glossary in issues, specs, proposals, hypotheses, and tests. If a needed concept is absent, reconsider the term or note the gap for `/domain-modeling`.

## ADR conflicts

If a proposal contradicts an existing ADR, identify the conflicting ADR and explain why the decision should be revisited.
