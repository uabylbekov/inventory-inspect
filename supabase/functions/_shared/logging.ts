type Primitive = string | number | boolean | null;
type LogValue = Primitive | Primitive[] | Record<string, unknown>;

const REDACTED_KEYS = [
  "authorization",
  "apikey",
  "token",
  "secret",
  "key",
  "webhook",
  "privatekey",
  "access_token",
  "refresh_token",
];

function shouldRedact(key: string) {
  const normalized = key.replace(/[_-]/g, "").toLowerCase();
  return REDACTED_KEYS.some((candidate) => normalized.includes(candidate));
}

function sanitize(value: unknown): LogValue | undefined {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }

  if (Array.isArray(value)) {
    return value
      .map((entry) => sanitize(entry))
      .filter((entry): entry is Primitive => {
        return (
          entry === null ||
          typeof entry === "string" ||
          typeof entry === "number" ||
          typeof entry === "boolean"
        );
      });
  }

  if (value && typeof value === "object") {
    const output: Record<string, unknown> = {};

    for (const [key, entry] of Object.entries(value)) {
      if (shouldRedact(key)) {
        output[key] = "[redacted]";
        continue;
      }

      const sanitized = sanitize(entry);
      if (sanitized !== undefined) {
        output[key] = sanitized;
      }
    }

    return output;
  }

  return undefined;
}

export function logStage(
  scope: string,
  stage: string,
  details: Record<string, unknown> = {},
) {
  console.log(`${scope} stage`, JSON.stringify({
    stage,
    ...sanitize(details),
  }));
}

export function logError(
  scope: string,
  error: unknown,
  details: Record<string, unknown> = {},
) {
  const message = error instanceof Error ? error.message : String(error);
  const stack = error instanceof Error ? error.stack : undefined;

  console.error(`${scope} error`, JSON.stringify({
    message,
    stack,
    ...sanitize(details),
  }));
}
