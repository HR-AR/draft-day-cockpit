import {
  parseRecommendation,
  recommendationPrompt,
  type DraftContext,
  type DraftRecommendation,
  type RecommendationProvider,
} from "./recommendation.ts";

type Fetch = typeof globalThis.fetch;

function jsonObject(text: string): unknown {
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first < 0 || last < first) throw new Error("MODEL_RESPONSE_INVALID: no JSON object returned");
  return JSON.parse(text.slice(first, last + 1));
}

async function responseJson(response: Response): Promise<any> {
  if (!response.ok) throw new Error(`MODEL_REQUEST_FAILED: HTTP ${response.status}`);
  return response.json();
}

export class OfflineExampleProvider implements RecommendationProvider {
  async recommend(context: DraftContext): Promise<DraftRecommendation> {
    const [pick, ...rest] = context.available;
    return Object.freeze({
      pick: pick.name,
      reason: "Offline example: selected the first supplied player; configure a model for strategic advice.",
      alternatives: Object.freeze(rest.slice(0, 2).map((player) => player.name)),
    });
  }
}

export class OpenAICompatibleProvider implements RecommendationProvider {
  private readonly options: Readonly<{
    endpoint: string;
    model: string;
    apiKey?: string;
    fetch?: Fetch;
  }>;

  constructor(options: OpenAICompatibleProvider["options"]) { this.options = options; }

  async recommend(context: DraftContext): Promise<DraftRecommendation> {
    const headers: Record<string, string> = { "content-type": "application/json" };
    if (this.options.apiKey) headers.authorization = `Bearer ${this.options.apiKey}`;
    const response = await (this.options.fetch ?? globalThis.fetch)(this.options.endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: this.options.model,
        temperature: 0.2,
        messages: [{ role: "user", content: recommendationPrompt(context) }],
      }),
    });
    const body = await responseJson(response);
    return parseRecommendation(jsonObject(body?.choices?.[0]?.message?.content ?? ""), context);
  }
}

export class AnthropicMessagesProvider implements RecommendationProvider {
  private readonly options: Readonly<{
    endpoint?: string;
    model: string;
    apiKey: string;
    fetch?: Fetch;
  }>;

  constructor(options: AnthropicMessagesProvider["options"]) { this.options = options; }

  async recommend(context: DraftContext): Promise<DraftRecommendation> {
    const response = await (this.options.fetch ?? globalThis.fetch)(
      this.options.endpoint ?? "https://api.anthropic.com/v1/messages",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": this.options.apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: this.options.model,
          max_tokens: 500,
          messages: [{ role: "user", content: recommendationPrompt(context) }],
        }),
      },
    );
    const body = await responseJson(response);
    const text = body?.content?.find((item: any) => item?.type === "text")?.text ?? "";
    return parseRecommendation(jsonObject(text), context);
  }
}
