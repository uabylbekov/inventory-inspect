import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"
import { logError, logStage } from "../_shared/logging.ts"

serve(async (req) => {
    try {
        logStage("push-notifications", "request.received", { method: req.method })
        const authHeader = req.headers.get('Authorization')
        const expectedToken = Deno.env.get('PUSH_NOTIFICATIONS_WEBHOOK_TOKEN')
        const serviceRoleToken = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
        const [bearer, token] = (authHeader ?? '').split(' ')

        if (!expectedToken && !serviceRoleToken) {
            logStage("push-notifications", "config.missing_webhook_token")
            return new Response("Missing push notification webhook configuration", { status: 500 })
        }

        const isAuthorized = bearer === 'Bearer'
            && token
            && (
                (expectedToken && token === expectedToken)
                || (serviceRoleToken && token === serviceRoleToken)
            )

        if (!isAuthorized) {
            logStage("push-notifications", "auth.unauthorized")
            return new Response("Unauthorized", { status: 401 })
        }

        const payload = await req.json()
        const { record } = payload

        if (!record || !record.user_id) {
            logStage("push-notifications", "payload.invalid")
            return new Response("Invalid payload", { status: 400 })
        }
        logStage("push-notifications", "payload.parsed", {
            userId: record.user_id,
            notificationId: record.id ?? null,
            type: record.type ?? null,
        })

        const supabase = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        )

        // 1. Fetch user's active device tokens
        const { data: tokens, error: tokenError } = await supabase
            .from('user_push_tokens')
            .select('device_token')
            .eq('user_id', record.user_id)

        if (tokenError) throw tokenError
        if (!tokens || tokens.length === 0) {
            logStage("push-notifications", "tokens.none_found", {
                userId: record.user_id,
            })
            return new Response("No tokens found", { status: 200 })
        }

        // 2. SMART BADGE: Count current unread notifications for this user
        // We fetch this count AFTER the insert that triggered this hook
        const { count: unreadCount } = await supabase
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', record.user_id)
            .eq('is_read', false)

        // 3. APNs Configuration
        const privateKey = Deno.env.get('APNS_PRIVATE_KEY')
        const keyId = Deno.env.get('APNS_KEY_ID')
        const teamId = Deno.env.get('APNS_TEAM_ID')
        const bundleId = Deno.env.get('APNS_BUNDLE_ID')
        const isProduction = Deno.env.get('APNS_ENVIRONMENT') === 'production'

        if (!privateKey || !keyId || !teamId || !bundleId) {
            logStage("push-notifications", "config.missing_apns")
            return new Response("Missing APNs configuration", { status: 500 })
        }

        const formattedKey = privateKey.replace(/\\n/g, '\n')
        const jwt = await new jose.SignJWT({})
            .setProtectedHeader({ alg: 'ES256', kid: keyId })
            .setIssuedAt()
            .setIssuer(teamId)
            .sign(await jose.importPKCS8(formattedKey, 'ES256'))

        const host = isProduction ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'

        // 4. Send to each device
        const results = await Promise.all(tokens.map(async (t) => {
            try {
                const response = await fetch(`https://${host}/3/device/${t.device_token}`, {
                    method: 'POST',
                    headers: {
                        'authorization': `bearer ${jwt}`,
                        'apns-topic': bundleId,
                        'apns-push-type': 'alert',
                        'apns-priority': '10',
                    },
                    body: JSON.stringify({
                        aps: {
                            alert: {
                                title: record.title,
                                body: record.body
                            },
                            sound: 'default',
                            badge: Number(unreadCount), // Use exact unread count from DB
                            "mutable-content": 1
                        },
                        data: {
                            id: record.id,
                            type: record.type,
                            ... (record.data || {})
                        }
                    })
                })

                // Cleanup dead tokens
                if (response.status === 410 || response.status === 404) {
                    await supabase
                        .from('user_push_tokens')
                        .delete()
                        .eq('device_token', t.device_token)
                }

                const errorBody = response.ok ? null : await response.text()
                if (!response.ok) {
                    console.error('push-notifications apns_delivery_failed', JSON.stringify({
                        status: response.status,
                        token: t.device_token,
                        body: errorBody || response.statusText,
                    }))
                }

                return {
                    token: t.device_token,
                    status: response.status,
                    ok: response.ok,
                }
            } catch (error) {
                console.error('push-notifications request_failed', JSON.stringify({
                    token: t.device_token,
                    error: error instanceof Error ? error.message : String(error),
                }))
                return {
                    token: t.device_token,
                    status: 500,
                    ok: false,
                }
            }
        }))

        const failed = results.filter((result) => !result.ok)
        const status = failed.length == results.length ? 502 : 200
        logStage("push-notifications", "request.completed", {
            userId: record.user_id,
            sent: results.length,
            failed: failed.length,
            status,
            badge: unreadCount,
        })

        return new Response(JSON.stringify({
            sent: results.length,
            badge: unreadCount,
            failed: failed.length,
        }), {
            headers: { "Content-Type": "application/json" },
            status
        })

    } catch (error) {
        logError("push-notifications", error)
        return new Response(error.message, { status: 500 })
    }
})
