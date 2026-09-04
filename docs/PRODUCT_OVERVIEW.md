# Product overview

Draft Day Cockpit answers one question during a live fantasy-football draft: who should I take now,
and what should I plan for before my next turn?

The macOS cockpit keeps the current recommendation, contingency branches, source freshness, room
identity, connection state, and write safety in one place. Yahoo stays visible and owner-attended.
The product does not sign in for the owner, read browser storage, or treat a stale tab as current
draft authority.

## Why it exists

Most draft tools stop at rankings. A real room changes pick by pick, and the useful answer depends on
who remains, the roster already built, the next turn, and whether the product can prove it is reading
the intended room. Draft Day Cockpit joins those facts while showing when one of them is missing.

## Current local release

- Native macOS cockpit with a supervised local helper.
- Owner-attended Yahoo selected-tab observation.
- Exact room, team-count, slot, and turn custody before draft actions are enabled.
- A two-part **NOW / THEN** recommendation surface.
- Explicit stale, disconnected, unauthorized-room, and halted states.
- Short-lived MOCK authorization for safe rehearsal.

The recommendation engine, player inputs, private league configuration, and live evidence are not
part of this public repository.
