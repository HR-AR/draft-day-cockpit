# Contributing

Open an issue before a large change. Small fixes may go directly to a pull request.

1. Use invented process IDs, paths, URLs, and room identifiers.
2. Add a test that fails before the fix.
3. Keep the patch inside the public boundary.
4. Run `swift test` and `cd node && npm test`.
5. Explain the failure mode and why the new test would catch a regression.

Maintainers may adapt accepted public patches into a separate private product after review. The
public repository never receives credentials or write access to that private repository.
