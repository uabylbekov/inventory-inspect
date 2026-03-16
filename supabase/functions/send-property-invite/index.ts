import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import { logError, logStage } from "../_shared/logging.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const normalizeRole = (role: string) => {
  const normalized = role.toLowerCase().trim()
  if (normalized === "cleaner") return "maintainer"
  if (normalized === "manager" || normalized === "maintainer") return normalized
  throw new Error("Invalid role")
}

serve(async (req) => {
  logStage("send-property-invite", "request.received", { method: req.method })

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { email, property_id, role } = await req.json()
    const normalizedRole = normalizeRole(role)
    logStage("send-property-invite", "payload.parsed", {
      propertyId: property_id,
      role: normalizedRole,
      emailDomain: typeof email === "string" ? email.split("@")[1] ?? null : null,
    })

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const authHeader = req.headers.get("Authorization")!
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user: caller } } = await adminClient.auth.getUser(
      authHeader.replace("Bearer ", "")
    )
    if (!caller) {
      logStage("send-property-invite", "auth.unauthorized")
      throw new Error("Unauthorized")
    }

    const [propertyRes, profileRes] = await Promise.all([
      adminClient.from("properties").select("name").eq("id", property_id).single(),
      adminClient.from("profiles").select("full_name").eq("id", caller.id).single(),
    ])

    const propertyName = propertyRes.data?.name ?? "a property"
    const inviterName = profileRes.data?.full_name ?? caller.email ?? "Someone"

    const { data: rpcResult, error: rpcError } = await userClient
      .rpc("invite_user_to_property", {
        p_email: email,
        p_property_id: property_id,
        p_role: normalizedRole,
      })

    if (rpcError) throw new Error(rpcError.message)

    const status = rpcResult?.status
    logStage("send-property-invite", "invite.rpc_completed", {
      propertyId: property_id,
      status,
    })

    if (status === "pending_created") {
      const appStoreUrl = Deno.env.get("APP_STORE_URL") ?? "https://apps.apple.com"

      await adminClient.auth.admin.inviteUserByEmail(email.toLowerCase().trim(), {
        data: {
          property_id,
          role: normalizedRole,
          invited_by: inviterName,
          property_name: propertyName,
        },
        redirectTo: appStoreUrl,
      })
      logStage("send-property-invite", "invite.email_sent", {
        propertyId: property_id,
      })
    }

    logStage("send-property-invite", "request.completed", {
      propertyId: property_id,
      status,
    })
    return new Response(
      JSON.stringify({ success: true, status }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    )

  } catch (error) {
    logError("send-property-invite", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    )
  }
})
