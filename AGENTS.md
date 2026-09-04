# Contributor instructions

This repository is the public competition surface for Draft Day Cockpit. Product documentation may
describe the fantasy-football workflow, but executable changes stay inside the browser-custody and
recovery-message boundary described in `docs/PUBLIC_BOUNDARY.md`.

- Never add real accounts, league IDs, room IDs, profile contents, cookies, headers, page bodies,
  tokens, local absolute paths, private repository history, recommendation logic, or projections.
- Use invented identifiers in tests and issues.
- Preserve the exact-profile and fail-closed guarantees.
- Add or update a test for every behavior change.
- Run `swift test` and `cd node && npm test` before submitting a pull request.
