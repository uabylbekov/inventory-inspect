import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"

serve(async (req) => {
    try {
        const payload = await req.json()
        const { record } = payload // The new notification row from the webhook

        if (!record || !record.user_id) {
            return new Response("Invalid payload", { status: 400 })
        }

        // 1. Setup Supabase Client
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        )

        // 2. Fetch user's registered device tokens
        const { data: tokens, error: tokenError } = await supabase
            .from('user_push_tokens')
            .select('device_token')
            .eq('user_id', record.user_id)

        if (tokenError) throw tokenError
        if (!tokens || tokens.length === 0) {
            console.log(`No tokens found for user ${record.user_id}`)
            return new Response("No tokens found", { status: 200 })
        }

        // 3. APNs Configuration
        const privateKey = Deno.env.get('APNS_PRIVATE_KEY') // The .p8 content
        const keyId = Deno.env.get('APNS_KEY_ID')
        const teamId = Deno.env.get('APNS_TEAM_ID')
        const bundleId = Deno.env.get('APNS_BUNDLE_ID')
        const isProduction = Deno.env.get('APNS_ENVIRONMENT') === 'production'

        if (!privateKey || !keyId || !teamId || !bundleId) {
            return new Response("Missing APNs configuration secrets", { status: 500 })
        }

        // 4. Generate APNs JWT
        // Ensure the private key is properly formatted with newlines if passed as a string
        const formattedKey = privateKey.replace(/\\n/g, '\n')

        let jwt;
        try {
            jwt = await new jose.SignJWT({})
                .setProtectedHeader({ alg: 'ES256', kid: keyId })
                .setIssuedAt()
                .setIssuer(teamId)
                .sign(await jose.importPKCS8(formattedKey, 'ES256'))
        } catch (e) {
            console.error("JWT Signing Error:", e)
            return new Response("Failed to sign APNs JWT", { status: 500 })
        }

        // 5. Send to Apple (APNs)
        const host = isProduction ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'

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
                            badge: 1,
                            "mutable-content": 1
                        },
                        data: record.data || {}
                    })
                })

                if (!response.ok) {
                    const errBody = await response.text()
                    console.error(`APNs Error for token ${t.device_token}:`, errBody)
                }

                return response.status
            } catch (e) {
                console.error(`Fetch Error for token ${t.device_token}:`, e)
                return 500
            }
        }))

        return new Response(JSON.stringify({ sent: results.length, statuses: results }), {
            headers: { "Content-Type": "application/json" },
            status: 200
        })

    } catch (error) {
        console.error("Main function error:", error)
        return new Response(error.message, { status: 500 })
    }
})
