export const LLM_ALLOWED_UNITS = ["g", "ml", "piece", "tbsp", "tsp", null] as const;
export const LLM_ALLOWED_CONFIDENCE = ["high", "medium", "low"] as const;

export type LLMIngredientUnit = (typeof LLM_ALLOWED_UNITS)[number];
export type LLMConfidence = (typeof LLM_ALLOWED_CONFIDENCE)[number];

export interface LLMRecipeIngredient {
  name: string;
  quantity: number | null;
  unit: LLMIngredientUnit;
  notes: string | null;
}

export interface LLMRecipeImportOutput {
  title: string;
  ingredients: LLMRecipeIngredient[];
  steps: string[];
  prepTimeMinutes: number | null;
  cookTimeMinutes: number | null;
  servings: number | null;
  confidence: LLMConfidence;
}

export const LLM_RECIPE_IMPORT_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "title",
    "ingredients",
    "steps",
    "prepTimeMinutes",
    "cookTimeMinutes",
    "servings",
    "confidence",
  ],
  properties: {
    title: { type: "string" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "quantity", "unit", "notes"],
        properties: {
          name: { type: "string" },
          quantity: { type: ["number", "null"] },
          unit: { enum: ["g", "ml", "piece", "tbsp", "tsp", null] },
          notes: { type: ["string", "null"] },
        },
      },
    },
    steps: {
      type: "array",
      items: { type: "string" },
    },
    prepTimeMinutes: { type: ["number", "null"] },
    cookTimeMinutes: { type: ["number", "null"] },
    servings: { type: ["number", "null"] },
    confidence: { enum: ["high", "medium", "low"] },
  },
} as const;

export const RECIPE_IMPORT_LLM_SYSTEM_PROMPT = `You are a strict recipe JSON extraction engine.

Return ONLY valid JSON.
Do not output markdown.
Do not output code fences.
Do not output explanations.
Do not output comments.
Do not output any text before or after JSON.

You MUST return an object with EXACTLY these keys:
- title: string
- ingredients: array of objects
- steps: array of strings
- prepTimeMinutes: number or null
- cookTimeMinutes: number or null
- servings: number or null
- confidence: one of "high", "medium", "low"

Each ingredient object MUST have EXACTLY these keys:
- name: string
- quantity: number or null
- unit: "g" | "ml" | "piece" | "tbsp" | "tsp" | null
- notes: string or null

Rules:
1) Preserve natural ingredient lines when uncertain.
2) If quantity is explicitly written in the caption (e.g. 200g, 60 g, 250ml, 1 piece), you MUST extract it as a numeric quantity + unit.
3) If quantity is unclear, use null.
4) If unit is unclear, use null.
5) Prefer null over guessing.
6) Do not invent ingredients not present in the caption.
7) Do not invent steps not present in the caption.
8) Do not infer prep/cook times unless explicitly stated.
9) Do not infer servings unless explicitly stated.
10) Keep ingredient names human-readable.
11) confidence should reflect extraction quality (high/medium/low), not certainty about cooking quality.
12) "prefer null over guessing" applies only when quantity is NOT explicitly present in the caption.

Example 1 (structured, high quality)
INPUT:
"""
Gyoza Lasagna
INGREDIENTI:
- 500g manzo
- 200ml vino bianco
- 1 cipolla
PROCEDIMENTO:
1. Soffriggi la cipolla.
2. Aggiungi manzo e vino.
3. Cuoci 20 minuti.
"""
OUTPUT:
{"title":"Gyoza Lasagna","ingredients":[{"name":"manzo","quantity":500,"unit":"g","notes":null},{"name":"vino bianco","quantity":200,"unit":"ml","notes":null},{"name":"cipolla","quantity":1,"unit":"piece","notes":null}],"steps":["Soffriggi la cipolla.","Aggiungi manzo e vino.","Cuoci 20 minuti."],"prepTimeMinutes":null,"cookTimeMinutes":20,"servings":null,"confidence":"high"}

Example 2 (messy social caption, low quality)
INPUT:
"""
OMG this was so good 😍
Made this tonight
#dinner #easy
"""
OUTPUT:
{"title":"OMG this was so good","ingredients":[],"steps":[],"prepTimeMinutes":null,"cookTimeMinutes":null,"servings":null,"confidence":"low"}

Example 3 (mixed quality)
INPUT:
"""
Pasta al limone
ingredienti
- 1/2 lemon
- 60g flour
- sale q.b.
steps
mix all, cook quickly
"""
OUTPUT:
{"title":"Pasta al limone","ingredients":[{"name":"lemon","quantity":0.5,"unit":"piece","notes":null},{"name":"flour","quantity":60,"unit":"g","notes":null},{"name":"sale","quantity":null,"unit":null,"notes":"q.b."}],"steps":["mix all, cook quickly"],"prepTimeMinutes":null,"cookTimeMinutes":null,"servings":null,"confidence":"medium"}`;

export function validateLLMRecipeImportOutput(payload: unknown): {
  ok: boolean;
  errors: string[];
  value?: LLMRecipeImportOutput;
} {
  const errors: string[] = [];

  if (!isRecord(payload)) {
    return { ok: false, errors: ["payload must be an object"] };
  }

  const expectedRootKeys = [
    "title",
    "ingredients",
    "steps",
    "prepTimeMinutes",
    "cookTimeMinutes",
    "servings",
    "confidence",
  ];

  for (const key of expectedRootKeys) {
    if (!(key in payload)) {
      errors.push(`missing root key: ${key}`);
    }
  }

  for (const key of Object.keys(payload)) {
    if (!expectedRootKeys.includes(key)) {
      errors.push(`unexpected root key: ${key}`);
    }
  }

  if (typeof payload.title !== "string") {
    errors.push("title must be a string");
  }

  if (!Array.isArray(payload.ingredients)) {
    errors.push("ingredients must be an array");
  }

  if (!Array.isArray(payload.steps)) {
    errors.push("steps must be an array");
  } else if (!payload.steps.every((step) => typeof step === "string")) {
    errors.push("steps must contain only strings");
  }

  if (!isNullableNumber(payload.prepTimeMinutes)) {
    errors.push("prepTimeMinutes must be a number or null");
  }

  if (!isNullableNumber(payload.cookTimeMinutes)) {
    errors.push("cookTimeMinutes must be a number or null");
  }

  if (!isNullableNumber(payload.servings)) {
    errors.push("servings must be a number or null");
  }

  if (!LLM_ALLOWED_CONFIDENCE.includes(payload.confidence as LLMConfidence)) {
    errors.push("confidence must be one of: high, medium, low");
  }

  if (Array.isArray(payload.ingredients)) {
    payload.ingredients.forEach((ingredient, index) => {
      if (!isRecord(ingredient)) {
        errors.push(`ingredients[${index}] must be an object`);
        return;
      }

      const expectedIngredientKeys = ["name", "quantity", "unit", "notes"];
      for (const key of expectedIngredientKeys) {
        if (!(key in ingredient)) {
          errors.push(`ingredients[${index}] missing key: ${key}`);
        }
      }
      for (const key of Object.keys(ingredient)) {
        if (!expectedIngredientKeys.includes(key)) {
          errors.push(`ingredients[${index}] unexpected key: ${key}`);
        }
      }

      if (typeof ingredient.name !== "string") {
        errors.push(`ingredients[${index}].name must be a string`);
      }
      if (!isNullableNumber(ingredient.quantity)) {
        errors.push(`ingredients[${index}].quantity must be a number or null`);
      }
      if (!LLM_ALLOWED_UNITS.includes(ingredient.unit as LLMIngredientUnit)) {
        errors.push(`ingredients[${index}].unit must be g|ml|piece|tbsp|tsp|null`);
      }
      if (!(typeof ingredient.notes === "string" || ingredient.notes === null)) {
        errors.push(`ingredients[${index}].notes must be a string or null`);
      }
    });
  }

  if (errors.length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    errors: [],
    value: payload as LLMRecipeImportOutput,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNullableNumber(value: unknown): value is number | null {
  return value === null || typeof value === "number";
}
