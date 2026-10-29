import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const listings = {
  "cam-1": { name: "Sony Alpha a7 III Camera Kit", pricePerDay: 600, deposit: 4000, available: true },
  "game-1": { name: "Nintendo Switch OLED", pricePerDay: 280, deposit: 1500, available: true },
  "tool-1": { name: "Bosch Cordless Drill", pricePerDay: 220, deposit: 2000, available: true },
  "sport-1": { name: "Coleman Camping Tent", pricePerDay: 260, deposit: 1800, available: false },
  "audio-1": { name: "JBL PartyBox 110", pricePerDay: 340, deposit: 2400, available: true },
  "home-1": { name: "Cuisinart Stand Mixer", pricePerDay: 180, deposit: 2500, available: true },
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const errorMessage = (error: unknown) =>
  error instanceof Error
    ? error.message
    : JSON.stringify(error) ?? String(error);

const isUuid = (value: string) =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const body = await request.json();
    const xenditSecretKey = Deno.env.get("XENDIT_SECRET_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!xenditSecretKey || !supabaseUrl || !serviceRoleKey) {
      console.error("Missing required payment function secrets.");
      return json({ error: "Payment service is not configured." }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const authorization = request.headers.get("authorization");
    const accessToken = authorization?.replace(/^Bearer\s+/i, "");
    if (!accessToken) {
      return json({ error: "Sign in before creating an order." }, 401);
    }

    const { data: userData, error: userError } = await admin.auth.getUser(
      accessToken,
    );
    if (userError || !userData.user) {
      return json({ error: "The signed-in user could not be verified." }, 401);
    }

    let amount: number;
    let description: string;

    if (typeof body.listing_id === "string") {
      let listing = listings[body.listing_id as keyof typeof listings];
      if (!listing && isUuid(body.listing_id)) {
        const { data: persistedListing, error } = await admin
          .from("rental_listings")
          .select("name, price_per_day, deposit, available")
          .eq("id", body.listing_id)
          .maybeSingle();
        if (error) throw error;
        if (persistedListing) {
          listing = {
            name: persistedListing.name,
            pricePerDay: Number(persistedListing.price_per_day),
            deposit: Number(persistedListing.deposit),
            available: persistedListing.available,
          };
        }
      }
      const days = body.days;
      if (!listing) return json({ error: "Rental listing was not found." }, 404);
      if (!listing.available) {
        return json({ error: "This rental is already booked." }, 409);
      }
      if (!Number.isInteger(days) || days < 1 || days > 30) {
        return json({ error: "Choose a rental duration from 1 to 30 days." }, 400);
      }

      const subtotal = listing.pricePerDay * days;
      amount = subtotal + Math.round(subtotal * 0.08) + listing.deposit;
      description = `Renting ${listing.name} for ${days} day(s)`;
    } else if (Number.isSafeInteger(body.product_id)) {
      const { data: product, error } = await admin
        .from("products")
        .select("id, name, price")
        .eq("id", body.product_id)
        .single();
      if (error) throw error;
      const productPrice = Number(product?.price);
      if (!product || !Number.isSafeInteger(productPrice) || productPrice <= 0) {
        return json({ error: "Product price is invalid." }, 400);
      }

      amount = productPrice;
      description = product.name;
    } else {
      return json({ error: "Provide a valid listing_id and days or product_id." }, 400);
    }

    const externalId = `rentit-${crypto.randomUUID()}`;
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return json({ error: "Invoice amount must be a positive whole number." }, 400);
    }

    const { error: orderError } = await admin.from("orders").insert({
      external_id: externalId,
      product_name: description,
      amount,
      status: "PENDING",
      owner_id: userData.user.id,
      ...(typeof body.listing_id === "string"
        ? { listing_id: body.listing_id }
        : {}),
      ...(Number.isSafeInteger(body.product_id)
        ? { product_id: body.product_id }
        : {}),
    });
    if (orderError) throw orderError;

    const invoicePayload = {
      external_id: externalId,
      amount,
      currency: "PHP",
      description,
      invoice_duration: 86400,
      // Leave payment_methods unset so Xendit displays the account-enabled options.
    };
    console.info("Creating Xendit invoice", {
      external_id: externalId,
      amount: invoicePayload.amount,
      currency: invoicePayload.currency,
    });

    const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(invoicePayload),
    });
    const invoice = await xenditResponse.json();

    if (!xenditResponse.ok) {
      await admin.from("orders").update({ status: "FAILED" }).eq("external_id", externalId);
      console.error("Xendit invoice request failed:", invoice);
      return json({ error: "Xendit could not create the invoice.", details: invoice }, 502);
    }

    if (typeof invoice.invoice_url !== "string") {
      throw new Error("Xendit returned an invalid invoice response.");
    }

    return json({ invoice_url: invoice.invoice_url, external_id: externalId });
  } catch (error) {
    const details = errorMessage(error);
    console.error("Invoice creation failed:", details);
    return json({ error: "Invoice creation failed.", details }, 500);
  }
});
