# Architecture

```text
Visible Yahoo draft room
        │ selected tab only
        ▼
Attended Tab Operator ── process/profile/tab/room evidence
        │ local authenticated bridge
        ▼
Supervised local helper ── freshness and fail-closed authority
        │ observed draft facts
        ▼
Recommendation provider contract ── offline example, local model, or frontier API
        │ NOW / THEN response
        ▼
Native Draft Day Cockpit
```

The public repository contains the attended Chrome lifecycle seam, its recovery contract, and a
small provider-neutral recommendation interface. The private repository owns the production helper
composition, scoring engine, prompts, data, acceptance evidence, and installed application.

## Safety rules

- A completed launch request is not proof that Chrome still exists.
- A matching Chrome process is not enough without the exact dedicated profile.
- A connected extension is not enough without selected-tab and room binding.
- A discovered MOCK room is not authorized until its observed size and slot are verified.
- Loss of custody halts writes instead of guessing.

Public fixes cross back through an allowlisted patch review. The public repository has no credential
or write path into the private product.
