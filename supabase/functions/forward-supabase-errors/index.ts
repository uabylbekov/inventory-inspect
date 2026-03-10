import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const MAX_EVENTS_PER_RUN = 12;
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
      where regexp_contains(lower(event_message), '(error|exception|fatal|panic)')
      order by timestamp desc
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
      order by timestamp desc
      limit 25
    `,
  },
  {
    key: "postgres_logs",
    label: "Postgres",
    sql: `
      select
        datetime(timestamp) as ts,
        parsed.error_severity as severity,
        event_message
      from postgres_logs
      cross join unnest(postgres_logs.metadata) as metadata
      cross join unnest(metadata.parsed) as parsed
      where parsed.error_severity in ('ERROR', 'FATAL', 'PANIC')
      order by timestamp desc
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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const expectedCronToken = Deno.env.get("ALERTS_CRON_TOKEN");
  const discordWebhook = Deno.env.get("DISCORD_ALERTS_WEBHOOK");
  const managementToken = Deno.env.get("ALERTS_MANAGEMENT_PAT");
  const projectRef = getProjectRef();

  if (!expectedCronToken || !discordWebhook || !managementToken || !projectRef) {
    return json({ error: "Required secrets are not configured." }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  const [bearer, token] = (authHeader ?? "").split(" ");
  if (bearer != "Bearer" || token != expectedCronToken) {
    return json({ error: "Unauthorized." }, 401);
  }

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  try {
    const now = new Date();
    const defaultStart = new Date(now.getTime() - INITIAL_LOOKBACK_MINUTES * 60_000);

    const { data: cursorRows, error: cursorError } = await adminClient
      .schema("ops")
      .from("supabase_alert_cursor")
      .select("source, last_checked_at");

    if (cursorError) throw cursorError;

    const cursorMap = new Map<string, string>(
      (cursorRows ?? []).map((row: { source: string; last_checked_at: string }) => [row.source, row.last_checked_at]),
    );

    const outboundLines: string[] = [];
    const cursorUpdates: { source: string; last_checked_at: string }[] = [];

    for (const source of sources) {
      const startIso = cursorMap.get(source.key) ?? defaultStart.toISOString();
      const endIso = now.toISOString();

      const logs = await fetchLogsForSource(projectRef, managementToken, source, startIso, endIso);

      for (const row of logs) {
        const ts = row.ts ?? endIso;
        const message = (row.event_message ?? "").trim();
        if (!message) continue;

        const eventKey = hashString(`${source.key}|${ts}|${message}`);
        const { error: dedupeError } = await adminClient
          .schema("ops")
          .from("supabase_alert_dedupe")
          .insert({
            event_key: eventKey,
            source: source.key,
            event_timestamp: ts,
          });

        if (dedupeError) {
          const duplicate = dedupeError.code === "23505" || dedupeError.message.toLowerCase().includes("duplicate");
          if (duplicate) continue;
          throw dedupeError;
        }

        const severityPrefix = row.severity ? `[${row.severity}] ` : "";
        outboundLines.push(
          `• ${source.label} | ${ts}\n${severityPrefix}${truncate(message, 800)}`
        );

        if (outboundLines.length >= MAX_EVENTS_PER_RUN) break;
      }

      cursorUpdates.push({
        source: source.key,
        last_checked_at: endIso,
      });

      if (outboundLines.length >= MAX_EVENTS_PER_RUN) break;
    }

    if (cursorUpdates.length > 0) {
      const { error: upsertError } = await adminClient
        .schema("ops")
        .from("supabase_alert_cursor")
        .upsert(cursorUpdates, { onConflict: "source" });
      if (upsertError) throw upsertError;
    }

    const cutoff = new Date(now.getTime() - DEDUPE_RETENTION_DAYS * 24 * 60 * 60_000).toISOString();
    await adminClient
      .schema("ops")
      .from("supabase_alert_dedupe")
      .delete()
      .lt("first_sent_at", cutoff);

    if (outboundLines.length === 0) {
      return json({ success: true, sent: 0 });
    }

    const discordResponse = await fetch(discordWebhook, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        content: `Supabase alerts for \`${projectRef}\`\n\n${truncate(outboundLines.join("\n\n"), 1800)}`,
      }),
    });

    if (!discordResponse.ok) {
      const message = await discordResponse.text();
      return json({ error: `Discord webhook failed: ${message || discordResponse.statusText}` }, 502);
    }

    return json({ success: true, sent: outboundLines.length });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected error." }, 500);
  }
});
