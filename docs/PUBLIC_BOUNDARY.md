# Public boundary

This repository may contain only the attended-browser lifecycle seam and sanitized reproductions.

## Allowed

- Exact-profile Chrome launch validation.
- Process and window lifecycle checks.
- Selected-tab connection and recovery-state contracts.
- Invented fixtures and deterministic tests.
- Documentation about the generic failure mode.

## Excluded

- Recommendation, scoring, ranking, draft, lineup, waiver, trade, or playoff logic.
- Player projections, training data, source captures, evaluation results, or private research.
- Real account, league, team, room, tab, session, or receipt identifiers.
- Browser profiles, cookies, storage, headers, page bodies, tokens, credentials, or key material.
- Runtime databases, installed-product evidence, internal task records, or private Git history.
- Competition prompts, judging material, or unpublished product plans.

The private repository is the source of truth. Transfer in either direction is controlled by an
allowlist, produces a reviewable diff, and must fail when an unexpected path appears.
