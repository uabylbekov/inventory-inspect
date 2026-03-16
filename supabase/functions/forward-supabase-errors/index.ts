import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { logError, logStage } from "../_shared/logging.ts";

type LogRow = {
  ts?: string;
  event_message?: string;
  severity?: string;
};

type SourceConfig = {
  key: string;
  label: string;
  sql: string;
};

type CursorRow = {
  source: string;
  last_checked_at: string;
};

type AlertCandidate = {
  source: string;
  eventKey: string;
  eventTimestamp: string;
  line: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const MAX_EVENTS_PER_RUN = 12;
const SOURCE_BATCH_LIMIT = 25;
const INITIAL_LOOKBACK_MINUTES = 5;
const DEDUPE_RETENTION_DAYS = 7;

const sources: SourceConfig[] = [
  {
    key: "function_logs",
    label: "Edge Functions",
    sql: `
      select
        datetime(timestamp) as ts,
        event_message
      from function_logs
      where regexp_contains(event_message, '^(GET|POST|PUT|PATCH|DELETE) \\| [45][0-9][0-9] \\|')
        and not regexp_contains(lower(event_message), 'forward-supabase-errors')
      order by timestamp asc
      limit 25
    `,
  },
  {
    key: "auth_logs",
    label: "Auth",
    sql: `
      select
        datetime(timestamp) as ts,
        event_message
      from auth_logs
      where regexp_contains(lower(event_message), '(error|fail|invalid|denied)')
      order by timestamp asc
      limit 25
    `,
  },
  {
    key: "postgres_logs",
    label: "Postgres",
    sql: `
      select
        datetime(timestamp) as ts,
        event_message
      from postgres_logs
      where regexp_contains(lower(event_message), '(error|fatal|panic)')
      order by timestamp asc
      limit 25
    `,
  },
];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function getProjectRef() {
  const explicit = Deno.env.get("SUPABASE_PROJECT_REF");
  if (explicit) return explicit;

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  try {
    return new URL(supabaseUrl).host.split(".")[0];
  } catch {
    return "";
  }
}

function truncate(value: string, maxLength: number) {
  return value.length > maxLength ? `${value.slice(0, maxLength - 1)}…` : value;
}

function hashString(input: string) {
  let hash = 2166136261;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return `h${(hash >>> 0).toString(16)}`;
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  if (error && typeof error === "object") {
    try {
      return JSON.stringify(error);
    } catch {
      return String(error);
    }
  }
  return "Unexpected error.";
}

async function fetchLogsForSource(
  projectRef: string,
  managementToken: string,
  source: SourceConfig,
  startIso: string,
  endIso: string,
) {
  const params = new URLSearchParams({
    sql: source.sql,
    iso_timestamp_start: startIso,
    iso_timestamp_end: endIso,
  });

  const response = await fetch(
    `https://api.supabase.com/v1/projects/${projectRef}/analytics/endpoints/logs.all?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${managementToken}`,
      },
    },
  );

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`Logs API failed for ${source.key}: ${message || response.statusText}`);
  }

  const payload = await response.json() as { result?: LogRow[]; error?: string | null };
  if (payload.error) {
    throw new Error(`Logs API query error for ${source.key}: ${payload.error}`);
  }

  return payload.result ?? [];
}

Deno.serve(async (req) => {
  logStage("forward-supabase-errors", "request.received", { method: req.method });

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    logStage("forward-supabase-errors", "request.invalid_method", { method: req.method });
    return json({ error: "Method not allowed." }, 405);
  }

  const expectedCronToken = Deno.env.get("ALERTS_CRON_TOKEN");
  const discordWebhook = Deno.env.get("DISCORD_ALERTS_WEBHOOK");
  const managementToken = Deno.env.get("ALERTS_MANAGEMENT_PAT");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const projectRef = getProjectRef();

  const missingConfig = [
    !expectedCronToken ? "ALERTS_CRON_TOKEN" : null,
    !discordWebhook ? "DISCORD_ALERTS_WEBHOOK" : null,
    !managementToken ? "ALERTS_MANAGEMENT_PAT" : null,
    !supabaseUrl ? "SUPABASE_URL" : null,
    !serviceRoleKey ? "SUPABASE_SERVICE_ROLE_KEY" : null,
    !projectRef ? "SUPABASE_PROJECT_REF" : null,
  ].filter((value): value is string => value !== null);

  if (missingConfig.length > 0) {
    logStage("forward-supabase-errors", "config.missing", { missingConfig });
    return json({ error: `Required secrets are not configured: ${missingConfig.join(", ")}` }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  const [bearer, token] = (authHeader ?? "").split(" ");
  if (bearer != "Bearer" || token != expectedCronToken) {
    logStage("forward-supabase-errors", "auth.unauthorized");
    return json({ error: "Unauthorized." }, 401);
  }

  const adminClient = createClient(
    supabaseUrl,
    serviceRoleKey,
  );

  try {
    const now = new Date();
    const defaultStart = new Date(now.getTime() - INITIAL_LOOKBACK_MINUTES * 60_000);

    const { data: cursorRows, error: cursorError } = await adminClient
      .rpc("get_supabase_alert_cursor");

    if (cursorError) {
      throw new Error(`Failed to load alert cursor: ${getErrorMessage(cursorError)}`);
    }

    const cursorMap = new Map<string, string>(
      ((cursorRows ?? []) as CursorRow[]).map((row) => [row.source, row.last_checked_at]),
    );

    const candidates: AlertCandidate[] = [];
    const cursorUpdates: { source: string; last_checked_at: string }[] = [];
    logStage("forward-supabase-errors", "scan.started", {
      sources: sources.map((source) => source.key),
    });

    for (const source of sources) {
      const storedCursor = cursorMap.get(source.key);
      const startIso = storedCursor ? new Date(storedCursor).toISOString() : defaultStart.toISOString();
      const endIso = now.toISOString();

      const logs = await fetchLogsForSource(projectRef, managementToken, source, startIso, endIso);
      logStage("forward-supabase-errors", "scan.source_loaded", {
        source: source.key,
        rowCount: logs.length,
      });
      let lastScannedTimestamp: string | null = null;
      let stoppedByRunLimit = false;

      for (const row of logs) {
        const ts = row.ts ?? endIso;
        const message = (row.event_message ?? "").trim();
        lastScannedTimestamp = ts;
        if (!message) continue;

        const eventKey = hashString(`${source.key}|${ts}|${message}`);
        const { data: alreadySent, error: dedupeCheckError } = await adminClient
          .rpc("supabase_alert_dedupe_exists", {
            p_event_key: eventKey,
          });

        if (dedupeCheckError) {
          throw new Error(`Failed to check alert dedupe for ${source.key}: ${getErrorMessage(dedupeCheckError)}`);
        }
        if (alreadySent === true) continue;

        const severityPrefix = row.severity ? `[${row.severity}] ` : "";
        candidates.push({
          source: source.key,
          eventKey,
          eventTimestamp: ts,
          line: `• ${source.label} | ${ts}\n${severityPrefix}${truncate(message, 800)}`,
        });

        if (candidates.length >= MAX_EVENTS_PER_RUN) {
          stoppedByRunLimit = true;
          break;
        }
      }

      cursorUpdates.push({
        source: source.key,
        last_checked_at: (!stoppedByRunLimit && logs.length < SOURCE_BATCH_LIMIT)
          ? endIso
          : (lastScannedTimestamp ?? endIso),
      });

      if (stoppedByRunLimit) break;
    }

    if (candidates.length === 0) {
      logStage("forward-supabase-errors", "scan.no_candidates");
      if (cursorUpdates.length > 0) {
        const { error: upsertError } = await adminClient
          .rpc("upsert_supabase_alert_cursor", {
            p_rows: cursorUpdates,
          });
        if (upsertError) {
          throw new Error(`Failed to store alert cursor: ${getErrorMessage(upsertError)}`);
        }
      }

      const cutoff = new Date(now.getTime() - DEDUPE_RETENTION_DAYS * 24 * 60 * 60_000).toISOString();
      const { error: cleanupError } = await adminClient
        .rpc("cleanup_supabase_alert_dedupe", {
          p_cutoff: cutoff,
        });
      if (cleanupError) {
        throw new Error(`Failed to clean alert dedupe: ${getErrorMessage(cleanupError)}`);
      }

      return json({ success: true, sent: 0 });
    }

    const discordResponse = await fetch(discordWebhook, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        content: `Supabase alerts for \`${projectRef}\`\n\n${truncate(candidates.map((candidate) => candidate.line).join("\n\n"), 1800)}`,
      }),
    });

    if (!discordResponse.ok) {
      const message = await discordResponse.text();
      logStage("forward-supabase-errors", "discord.failed", {
        status: discordResponse.status,
        candidateCount: candidates.length,
      });
      return json({ error: `Discord webhook failed: ${message || discordResponse.statusText}` }, 502);
    }

    for (const candidate of candidates) {
      const { error: dedupeError } = await adminClient
        .rpc("insert_supabase_alert_dedupe", {
          p_event_key: candidate.eventKey,
          p_source: candidate.source,
          p_event_timestamp: candidate.eventTimestamp,
        });

      if (dedupeError) {
        throw new Error(`Failed to mark alert as sent for ${candidate.source}: ${getErrorMessage(dedupeError)}`);
      }
    }

    if (cursorUpdates.length > 0) {
      const { error: upsertError } = await adminClient
        .rpc("upsert_supabase_alert_cursor", {
          p_rows: cursorUpdates,
        });
      if (upsertError) {
        throw new Error(`Failed to store alert cursor: ${getErrorMessage(upsertError)}`);
      }
    }

    const cutoff = new Date(now.getTime() - DEDUPE_RETENTION_DAYS * 24 * 60 * 60_000).toISOString();
    const { error: cleanupError } = await adminClient
      .rpc("cleanup_supabase_alert_dedupe", {
        p_cutoff: cutoff,
      });
    if (cleanupError) {
      throw new Error(`Failed to clean alert dedupe: ${getErrorMessage(cleanupError)}`);
    }

    logStage("forward-supabase-errors", "request.completed", {
      sent: candidates.length,
      cursorUpdates: cursorUpdates.length,
    });
    return json({ success: true, sent: candidates.length });
  } catch (error) {
    const message = getErrorMessage(error);
    logError("forward-supabase-errors", error);
    return json({ error: message }, 500);
  }
});
