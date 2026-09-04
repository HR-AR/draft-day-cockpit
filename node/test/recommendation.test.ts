import assert from "node:assert/strict";
import test from "node:test";
import { parseRecommendation, type DraftContext } from "../src/recommendation.ts";
import { AnthropicMessagesProvider, OpenAICompatibleProvider } from "../src/providers.ts";

const context: DraftContext = {
  teamCount: 10,
  slot: 4,
  round: 3,
  pick: 24,
  roster: [{ name: "Roster Runner", position: "RB" }],
  available: [
    { name: "Example Receiver", position: "WR" },
    { name: "Example Runner", position: "RB" },
  ],
};

test("rejects a model pick that is not available", () => {
  assert.throws(() => parseRecommendation({
    pick: "Invented Player", reason: "bad", alternatives: [],
  }, context), /outside the available list/u);
});

test("OpenAI-compatible providers receive only the supplied draft context", async () => {
  let requestBody = "";
  const provider = new OpenAICompatibleProvider({
    endpoint: "http://127.0.0.1:11434/v1/chat/completions",
    model: "local-model",
    fetch: async (_url, init) => {
      requestBody = String(init?.body);
      return new Response(JSON.stringify({ choices: [{ message: { content:
        '{"pick":"Example Receiver","reason":"roster balance","alternatives":["Example Runner"]}' } }] }));
    },
  });
  assert.equal((await provider.recommend(context)).pick, "Example Receiver");
  assert.match(requestBody, /Example Receiver/u);
});

test("Anthropic Messages responses use the same validated contract", async () => {
  const provider = new AnthropicMessagesProvider({
    model: "frontier-model",
    apiKey: "fixture-key",
    fetch: async () => new Response(JSON.stringify({ content: [{ type: "text", text:
      '{"pick":"Example Runner","reason":"position need","alternatives":[]}' }] })),
  });
  assert.equal((await provider.recommend(context)).pick, "Example Runner");
});
