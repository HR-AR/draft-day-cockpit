# Model providers

The public contract can request a recommendation from a model without exposing the private Draft
Day Cockpit engine. It sends only the draft context supplied to the command and rejects any pick or
alternative that is not in the supplied available-player list.

Use the offline adapter to inspect the response shape without network access:

```bash
cd node
node --experimental-strip-types src/cli.ts < ../examples/draft-context.json
```

For Ollama, LM Studio, vLLM, or another OpenAI-compatible local server:

```bash
export DRAFT_DAY_PROVIDER=openai-compatible
export DRAFT_DAY_MODEL=your-local-model
export DRAFT_DAY_ENDPOINT=http://127.0.0.1:11434/v1/chat/completions
node --experimental-strip-types src/cli.ts < ../examples/draft-context.json
```

The same adapter can use a compatible hosted endpoint by setting `DRAFT_DAY_ENDPOINT` and
`DRAFT_DAY_API_KEY`. The Anthropic Messages adapter uses `DRAFT_DAY_PROVIDER=anthropic`,
`DRAFT_DAY_MODEL`, and `DRAFT_DAY_API_KEY`.

API keys are not stored by this repository. A provider's web or CLI subscription is not generally
an API credential; users must follow that provider's terms and billing rules. Model output is advice,
not authority over the observed room, and this public example never submits a draft pick.
