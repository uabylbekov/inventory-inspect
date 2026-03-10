import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type FeedbackPayload = {
  category?: string;
  category_label?: string;
  message?: string;
  user_name?: string;
  personal_tier?: string;
  app_version?: string;
  build_number?: string;
  ios_version?: string;
  locale_identifier?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const categoryColors: Record<string, number> = {
  bug: 0xef4444,
  feature_request: 0x2563eb,
  billing: 0xf59e0b,
  usability: 0x10b981,
  other: 0x6b7280,
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function truncate(value: string, maxLength: number) {
  return value.length > maxLength ? `${value.slice(0, maxLength - 1)}…` : value;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const webhookUrl = Deno.env.get("DISCORD_FEEDBACK_WEBHOOK");
  if (!webhookUrl) {
    return json({ error: "Discord feedback webhook is not configured." }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing authorization header." }, 401);
  }

  const [bearer, token] = authHeader.split(" ");
  if (bearer !== "Bearer" || !token) {
    return json({ error: "Authorization header must be in Bearer format." }, 401);
  }

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    },
  );

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  try {
    const payload = (await req.json()) as FeedbackPayload;
    const message = payload.message?.trim() ?? "";
    const category = payload.category ?? "other";
    const categoryLabel = payload.category_label ?? "Other";

    if (message.length < 10) {
      return json({ error: "Feedback message is too short." }, 400);
    }

    const { data: claimsData, error: claimsError } = await userClient.auth.getClaims(token);
    const userId = claimsData?.claims?.sub;
    const userEmail = claimsData?.claims?.email;

    if (claimsError || !userId) {
      return json({ error: "Unable to verify the current user." }, 401);
    }

    const { data: profile } = await adminClient
      .from("profiles")
      .select("full_name, subscription_tier")
      .eq("id", userId)
      .maybeSingle();

    const displayName = profile?.full_name || payload.user_name || userEmail || userId;
    const tier = profile?.subscription_tier || payload.personal_tier || "free";
    const appVersion = payload.app_version || "unknown";
    const buildNumber = payload.build_number || "unknown";
    const iosVersion = payload.ios_version || "unknown";
    const locale = payload.locale_identifier || "unknown";

    const discordPayload = {
      content: "New in-app feedback submitted",
      embeds: [
        {
          title: `Snapshots Feedback: ${categoryLabel}`,
          color: categoryColors[category] ?? categoryColors.other,
          description: truncate(message, 4000),
          fields: [
            { name: "User", value: truncate(String(displayName), 1024), inline: true },
            { name: "Email", value: truncate(userEmail ?? "unknown", 1024), inline: true },
            { name: "Plan", value: truncate(String(tier), 1024), inline: true },
            { name: "Version", value: truncate(`${appVersion} (${buildNumber})`, 1024), inline: true },
            { name: "iOS", value: truncate(String(iosVersion), 1024), inline: true },
            { name: "Locale", value: truncate(String(locale), 1024), inline: true },
            { name: "User ID", value: truncate(userId, 1024), inline: false },
          ],
          timestamp: new Date().toISOString(),
        },
      ],
    };

    const discordResponse = await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(discordPayload),
    });

    if (!discordResponse.ok) {
      const responseText = await discordResponse.text();
      return json(
        { error: `Discord webhook request failed: ${responseText || discordResponse.statusText}` },
        502,
      );
    }

    return json({ success: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected error." }, 500);
  }
});
