import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library";
import { Buffer } from "node:buffer";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
};

const PRO_PRODUCT_IDS = [
  "dev.ukulabs.snapshots.pro.monthly",
  "dev.ukulabs.snapshots.pro.yearly",
];

const APPLE_ROOT_CA_URLS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
];

type NotificationRequest = {
  signedPayload?: string;
};

type DecodedNotification = {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
  data?: {
    appAppleId?: number;
    bundleId?: string;
    environment?: string;
    signedRenewalInfo?: string;
    signedTransactionInfo?: string;
  };
};

type DecodedTransaction = {
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  environment?: string;
  transactionId?: string;
  originalTransactionId?: string;
  purchaseDate?: number;
};

type DecodedRenewalInfo = {
  autoRenewProductId?: string;
  originalTransactionId?: string;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

let appleRootCAsPromise: Promise<Buffer[]> | null = null;

function toIsoString(epochMs?: number) {
  return epochMs ? new Date(epochMs).toISOString() : null;
}

async function loadAppleRootCAs() {
  if (!appleRootCAsPromise) {
    appleRootCAsPromise = Promise.all(
      APPLE_ROOT_CA_URLS.map(async (url) => {
        const response = await fetch(url);
        if (!response.ok) {
          throw new Error(`Failed to load Apple root certificate from ${url}.`);
        }

        return Buffer.from(await response.arrayBuffer());
      }),
    );
  }

  return appleRootCAsPromise;
}

function decodePayloadWithoutVerification<T>(signedValue: string): T {
  const [, payload] = signedValue.split(".");
  if (!payload) {
    throw new Error("Malformed signed payload.");
  }

  const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const decoded = atob(normalized + padding);
  return JSON.parse(
    new TextDecoder().decode(Uint8Array.from(decoded, (char) => char.charCodeAt(0))),
  ) as T;
}

async function buildVerifier(environment: Environment) {
  const bundleId = Deno.env.get("APP_STORE_BUNDLE_ID");
  if (!bundleId) {
    throw new Error("APP_STORE_BUNDLE_ID is required for App Store notification verification.");
  }

  const appAppleIdRaw = Deno.env.get("APP_STORE_APPLE_ID");
  const appAppleId = appAppleIdRaw ? Number(appAppleIdRaw) : undefined;
  if (environment === Environment.PRODUCTION && !appAppleId) {
    throw new Error(
      "APP_STORE_APPLE_ID is required to verify production App Store Server Notifications.",
    );
  }

  const appleRootCAs = await loadAppleRootCAs();
  return new SignedDataVerifier(
    appleRootCAs,
    true,
    environment,
    bundleId,
    appAppleId,
  );
}

async function verifyNotification(signedPayload: string) {
  const unsignedPayload = decodePayloadWithoutVerification<DecodedNotification>(signedPayload);
  const candidateEnvironment = unsignedPayload.data?.environment === "Production"
    ? Environment.PRODUCTION
    : Environment.SANDBOX;

  const primaryVerifier = await buildVerifier(candidateEnvironment);

  try {
    const notification = await primaryVerifier.verifyAndDecodeNotification(signedPayload);
    return { notification, verifier: primaryVerifier, environment: candidateEnvironment };
  } catch (primaryError) {
    const fallbackEnvironment = candidateEnvironment === Environment.SANDBOX
      ? Environment.PRODUCTION
      : Environment.SANDBOX;
    const fallbackVerifier = await buildVerifier(fallbackEnvironment);
    try {
      const notification = await fallbackVerifier.verifyAndDecodeNotification(signedPayload);
      return { notification, verifier: fallbackVerifier, environment: fallbackEnvironment };
    } catch {
      throw primaryError;
    }
  }
}

async function decodeTransactionAndRenewal(
  verifier: SignedDataVerifier,
  notification: DecodedNotification,
) {
  const signedTransactionInfo = notification.data?.signedTransactionInfo;
  const signedRenewalInfo = notification.data?.signedRenewalInfo;

  const transaction = signedTransactionInfo
    ? await verifier.verifyAndDecodeTransaction(signedTransactionInfo) as DecodedTransaction
    : null;
  const renewal = signedRenewalInfo
    ? await verifier.verifyAndDecodeRenewalInfo(signedRenewalInfo) as DecodedRenewalInfo
    : null;

  return { transaction, renewal };
}

function resolveSubscriptionState(
  transaction: DecodedTransaction | null,
  renewal: DecodedRenewalInfo | null,
  environment: Environment,
) {
  const productId = transaction?.productId ?? renewal?.autoRenewProductId ?? null;
  const expiresDate = transaction?.expiresDate;
  const revoked = Boolean(transaction?.revocationDate);
  const active = Boolean(
    productId &&
      PRO_PRODUCT_IDS.includes(productId) &&
      !revoked &&
      (!expiresDate || expiresDate > Date.now()),
  );

  return {
    active,
    tier: active ? "pro" : "free",
    productId,
    expiresAt: toIsoString(expiresDate),
    environment: transaction?.environment ?? (environment === Environment.PRODUCTION ? "Production" : "Sandbox"),
    transactionId: transaction?.transactionId ?? null,
    originalTransactionId: transaction?.originalTransactionId ?? renewal?.originalTransactionId ?? null,
  };
}

async function findExistingNotification(
  adminClient: ReturnType<typeof createClient>,
  notificationUUID: string,
) {
  const { data, error } = await adminClient
    .from("app_store_server_notifications")
    .select("id")
    .eq("notification_uuid", notificationUUID)
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data;
}

async function recordNotification(
  adminClient: ReturnType<typeof createClient>,
  payload: {
    notificationUUID: string;
    notificationType: string;
    subtype: string | null;
    originalTransactionId: string | null;
    transactionId: string | null;
    productId: string | null;
    environment: string | null;
    signedPayload: string;
    syncedProfileCount: number;
  },
) {
  const { error } = await adminClient.from("app_store_server_notifications").insert({
    notification_uuid: payload.notificationUUID,
    notification_type: payload.notificationType,
    subtype: payload.subtype,
    app_store_original_transaction_id: payload.originalTransactionId,
    app_store_transaction_id: payload.transactionId,
    app_store_product_id: payload.productId,
    environment: payload.environment,
    signed_payload: payload.signedPayload,
    synced_profile_count: payload.syncedProfileCount,
  });

  if (error) {
    throw new Error(error.message);
  }
}

async function syncBoundProfiles(
  adminClient: ReturnType<typeof createClient>,
  originalTransactionId: string,
  subscription: ReturnType<typeof resolveSubscriptionState>,
) {
  const { data: profiles, error: profileLookupError } = await adminClient
    .from("profiles")
    .select("id")
    .eq("app_store_original_transaction_id", originalTransactionId);

  if (profileLookupError) {
    throw new Error(profileLookupError.message);
  }

  if (!profiles || profiles.length === 0) {
    return 0;
  }

  const { error: updateError } = await adminClient
    .from("profiles")
    .update({
      app_store_product_id: subscription.productId,
      app_store_subscription_active: subscription.active,
      app_store_subscription_expires_at: subscription.expiresAt,
      app_store_environment: subscription.environment,
      app_store_last_synced_at: new Date().toISOString(),
    })
    .eq("app_store_original_transaction_id", originalTransactionId);

  if (updateError) {
    throw new Error(updateError.message);
  }

  return profiles.length;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { signedPayload }: NotificationRequest = await req.json();

    if (!signedPayload) {
      return json({ error: "signedPayload is required." }, 400);
    }

    const { notification, verifier, environment } = await verifyNotification(signedPayload);
    const notificationUUID = notification.notificationUUID;
    const notificationType = notification.notificationType ?? "UNKNOWN";

    if (!notificationUUID) {
      return json({ error: "notificationUUID is missing from the verified payload." }, 400);
    }

    const duplicate = await findExistingNotification(adminClient, notificationUUID);
    if (duplicate) {
      return json({ ok: true, duplicate: true }, 200);
    }

    const { transaction, renewal } = await decodeTransactionAndRenewal(
      verifier,
      notification as DecodedNotification,
    );
    const subscription = resolveSubscriptionState(transaction, renewal, environment);
    const syncedProfileCount = subscription.originalTransactionId
      ? await syncBoundProfiles(adminClient, subscription.originalTransactionId, subscription)
      : 0;

    await recordNotification(adminClient, {
      notificationUUID,
      notificationType,
      subtype: notification.subtype ?? null,
      originalTransactionId: subscription.originalTransactionId,
      transactionId: subscription.transactionId,
      productId: subscription.productId,
      environment: subscription.environment,
      signedPayload,
      syncedProfileCount,
    });

    return json({
      ok: true,
      notificationUUID,
      notificationType,
      subtype: notification.subtype ?? null,
      syncedProfileCount,
      originalTransactionId: subscription.originalTransactionId,
      active: subscription.active,
      tier: subscription.tier,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error.";
    console.error("app-store-server-notifications error", message);
    return json({ error: message }, 400);
  }
});
