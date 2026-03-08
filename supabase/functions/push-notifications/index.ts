import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"

serve(async (req) => {
    try {
        const payload = await req.json()
        const { record } = payload

        if (!record || !record.user_id) {
            return new Response("Invalid payload", { status: 400 })
        }

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

                return response.status
            } catch (e) {
                return 500
            }
        }))

        return new Response(JSON.stringify({ sent: results.length, badge: unreadCount }), {
            headers: { "Content-Type": "application/json" },
            status: 200
        })

    } catch (error) {
        return new Response(error.message, { status: 500 })
    }
})
