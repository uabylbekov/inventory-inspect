import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import { SignJWT, importPKCS8 } from "npm:jose@5.9.6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PRO_PRODUCT_IDS = [
  "dev.ukulabs.snapshots.pro.monthly",
  "dev.ukulabs.snapshots.pro.yearly",
];

type AppleTransaction = {
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  environment?: string;
  transactionId?: string;
  originalTransactionId?: string;
  purchaseDate?: number;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

function decodeBase64Url(value: string) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(normalized + padding);
  return new TextDecoder().decode(Uint8Array.from(binary, (char) => char.charCodeAt(0)));
}

function decodeSignedTransaction(signedTransaction: string): AppleTransaction {
  const [, payload] = signedTransaction.split(".");
  if (!payload) {
    throw new Error("Malformed signed transaction payload.");
  }

  return JSON.parse(decodeBase64Url(payload));
}

function toIsoString(epochMs?: number) {
  return epochMs ? new Date(epochMs).toISOString() : null;
}

async function buildAppStoreToken() {
  const issuerId = Deno.env.get("APP_STORE_ISSUER_ID");
  const keyId = Deno.env.get("APP_STORE_KEY_ID");
  const privateKey = Deno.env.get("APP_STORE_PRIVATE_KEY");
  const bundleId = Deno.env.get("APP_STORE_BUNDLE_ID");

  if (!issuerId || !keyId || !privateKey || !bundleId) {
    throw new Error(
      "App Store Server API credentials are incomplete. Configure APP_STORE_ISSUER_ID, APP_STORE_KEY_ID, APP_STORE_PRIVATE_KEY, and APP_STORE_BUNDLE_ID.",
    );
  }

  const signingKey = await importPKCS8(privateKey.replace(/\\n/g, "\n"), "ES256");
  console.log("app-store-token-config", JSON.stringify({
    issuerIdPresent: Boolean(issuerId),
    issuerIdPrefix: issuerId?.slice(0, 8) ?? null,
    keyId,
    bundleId,
    privateKeyPresent: Boolean(privateKey),
  }));

  return await new SignJWT({ bid: bundleId })
    .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
    .setIssuer(issuerId)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(signingKey);
}

async function fetchTransactionHistory(transactionId: string, appStoreToken: string) {
  const environments = [
    { baseUrl: "https://api.storekit.itunes.apple.com", environment: "Production" },
    { baseUrl: "https://api.storekit-sandbox.itunes.apple.com", environment: "Sandbox" },
  ];

  const query = new URLSearchParams({
    sort: "DESCENDING",
  });

  for (const candidate of environments) {
    console.log("app-store-history-request", JSON.stringify({
      environment: candidate.environment,
      bundleId: Deno.env.get("APP_STORE_BUNDLE_ID"),
      transactionId,
      endpointVersion: "v2",
      query: query.toString(),
    }));
    const response = await fetch(
      `${candidate.baseUrl}/inApps/v2/history/${encodeURIComponent(transactionId)}?${query.toString()}`,
      {
        headers: {
          Authorization: `Bearer ${appStoreToken}`,
          "Content-Type": "application/json",
        },
      },
    );

    if (response.status === 404 || (response.status >= 400 && response.status < 500)) {
      const message = await response.text();
      console.warn("app-store-history-response", JSON.stringify({
        environment: candidate.environment,
        status: response.status,
        body: message || response.statusText,
      }));
      continue;
    }

    if (!response.ok) {
      const message = await response.text();
      console.error("app-store-history-response", JSON.stringify({
        environment: candidate.environment,
        status: response.status,
        body: message || response.statusText,
      }));
      throw new Error(`App Store history lookup failed: ${message || response.statusText}`);
    }

    const payload = await response.json();
    const signedTransactions: string[] = payload.signedTransactions ?? [];
    const transactions = signedTransactions.map(decodeSignedTransaction);
    return {
      environment: candidate.environment,
      transactions,
    };
  }

  return {
    environment: null,
    transactions: [] as AppleTransaction[],
  };
}

function resolveSubscriptionState(transactions: AppleTransaction[]) {
  const sortedTransactions = [...transactions].sort((lhs, rhs) => {
    const lhsSort = lhs.expiresDate ?? lhs.purchaseDate ?? 0;
    const rhsSort = rhs.expiresDate ?? rhs.purchaseDate ?? 0;
    return rhsSort - lhsSort;
  });

  const now = Date.now();
  const activeTransaction = sortedTransactions.find((transaction) =>
    PRO_PRODUCT_IDS.includes(transaction.productId ?? "") &&
    !transaction.revocationDate &&
    (!transaction.expiresDate || transaction.expiresDate > now)
  );

  const latestTransaction = activeTransaction ?? sortedTransactions[0] ?? null;

  return {
    active: Boolean(activeTransaction),
    tier: activeTransaction ? "pro" : "free",
    productId: latestTransaction?.productId ?? null,
    expiresAt: toIsoString(latestTransaction?.expiresDate),
    environment: latestTransaction?.environment ?? null,
    transactionId: latestTransaction?.transactionId ?? null,
    originalTransactionId: latestTransaction?.originalTransactionId ?? null,
  };
}

async function assertTransactionOwnership(
  adminClient: ReturnType<typeof createClient>,
  originalTransactionId: string,
  userId: string,
) {
  const { data, error } = await adminClient
    .from("profiles")
    .select("id")
    .eq("app_store_original_transaction_id", originalTransactionId)
    .neq("id", userId)
    .limit(1);

  if (error) {
    throw new Error(error.message);
  }

  if ((data ?? []).length > 0) {
    return json(
      { error: "This App Store subscription is already linked to another account." },
      409,
    );
  }

  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header." }, 401);
    }

    const { transactionId } = await req.json();
    if (!transactionId || typeof transactionId !== "string") {
      return json({ error: "transactionId is required." }, 400);
    }

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: { user }, error: authError } = await adminClient.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (authError || !user) {
      return json({ error: "Unauthorized." }, 401);
    }

    const appStoreToken = await buildAppStoreToken();
    const history = await fetchTransactionHistory(transactionId, appStoreToken);
    if (history.transactions.length === 0) {
      return json(
        { error: "No verified App Store transaction history was found for this transactionId." },
        404,
      );
    }

    const subscription = resolveSubscriptionState(history.transactions);
    const originalTransactionId = subscription.originalTransactionId ?? transactionId;
    const ownershipConflict = await assertTransactionOwnership(
      adminClient,
      originalTransactionId,
      user.id,
    );
    if (ownershipConflict) {
      return ownershipConflict;
    }

    const { error: updateError } = await adminClient
      .from("profiles")
      .update({
        app_store_original_transaction_id: originalTransactionId,
        app_store_product_id: subscription.productId,
        app_store_subscription_active: subscription.active,
        app_store_subscription_expires_at: subscription.expiresAt,
        app_store_environment: subscription.environment ?? history.environment,
        app_store_last_synced_at: new Date().toISOString(),
      })
      .eq("id", user.id);

    if (updateError) {
      throw new Error(updateError.message);
    }

    return json(subscription, 200);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error." }, 400);
  }
});
