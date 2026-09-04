export type DraftPlayer = Readonly<{ name: string; position: string }>;

export type DraftContext = Readonly<{
  teamCount: number;
  slot: number;
  round: number;
  pick: number;
  roster: readonly DraftPlayer[];
  available: readonly DraftPlayer[];
  scoringNote?: string;
}>;

export type DraftRecommendation = Readonly<{
  pick: string;
  reason: string;
  alternatives: readonly string[];
}>;

export interface RecommendationProvider {
  recommend(context: DraftContext): Promise<DraftRecommendation>;
}

export function assertDraftContext(value: unknown): asserts value is DraftContext {
  if (!value || typeof value !== "object") throw new Error("DRAFT_CONTEXT_INVALID: expected an object");
  const context = value as Partial<DraftContext>;
  for (const key of ["teamCount", "slot", "round", "pick"] as const) {
    if (!Number.isInteger(context[key]) || Number(context[key]) < 1) {
      throw new Error(`DRAFT_CONTEXT_INVALID: ${key} must be a positive integer`);
    }
  }
  if (!Array.isArray(context.roster) || !Array.isArray(context.available) || context.available.length === 0) {
    throw new Error("DRAFT_CONTEXT_INVALID: roster and non-empty available lists are required");
  }
  for (const player of [...context.roster, ...context.available]) {
    if (!player || typeof player.name !== "string" || typeof player.position !== "string") {
      throw new Error("DRAFT_CONTEXT_INVALID: every player needs a name and position");
    }
  }
}

export function parseRecommendation(value: unknown, context: DraftContext): DraftRecommendation {
  if (!value || typeof value !== "object") throw new Error("RECOMMENDATION_INVALID: expected an object");
  const result = value as Partial<DraftRecommendation>;
  if (typeof result.pick !== "string" || typeof result.reason !== "string" ||
      !Array.isArray(result.alternatives) || !result.alternatives.every((item) => typeof item === "string")) {
    throw new Error("RECOMMENDATION_INVALID: expected pick, reason, and alternatives");
  }
  const available = new Set(context.available.map((player) => player.name));
  if (!available.has(result.pick) || result.alternatives.some((name) => !available.has(name))) {
    throw new Error("RECOMMENDATION_INVALID: model named a player outside the available list");
  }
  return Object.freeze({ pick: result.pick, reason: result.reason, alternatives: Object.freeze([...result.alternatives]) });
}

export function recommendationPrompt(context: DraftContext): string {
  return [
    "Recommend one fantasy-football draft pick from the available list.",
    "Return JSON only with keys pick, reason, alternatives.",
    "Never name a player outside the available list.",
    JSON.stringify(context),
  ].join("\n");
}
