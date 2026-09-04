import { assertDraftContext, type RecommendationProvider } from "./recommendation.ts";
import { AnthropicMessagesProvider, OfflineExampleProvider, OpenAICompatibleProvider } from "./providers.ts";

function providerFromEnvironment(): RecommendationProvider {
  const provider = process.env.DRAFT_DAY_PROVIDER ?? "offline";
  const model = process.env.DRAFT_DAY_MODEL ?? "";
  if (provider === "offline") return new OfflineExampleProvider();
  if (!model) throw new Error("DRAFT_DAY_MODEL is required for a model provider");
  if (provider === "openai-compatible") {
    return new OpenAICompatibleProvider({
      endpoint: process.env.DRAFT_DAY_ENDPOINT ?? "http://127.0.0.1:11434/v1/chat/completions",
      model,
      apiKey: process.env.DRAFT_DAY_API_KEY,
    });
  }
  if (provider === "anthropic") {
    if (!process.env.DRAFT_DAY_API_KEY) throw new Error("DRAFT_DAY_API_KEY is required for Anthropic");
    return new AnthropicMessagesProvider({ model, apiKey: process.env.DRAFT_DAY_API_KEY });
  }
  throw new Error(`Unknown DRAFT_DAY_PROVIDER: ${provider}`);
}

const chunks: Buffer[] = [];
for await (const chunk of process.stdin) chunks.push(Buffer.from(chunk));
const input = JSON.parse(Buffer.concat(chunks).toString("utf8"));
assertDraftContext(input);
const result = await providerFromEnvironment().recommend(input);
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
