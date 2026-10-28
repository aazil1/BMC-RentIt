import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const body = await request.json();
    if (typeof body.external_id !== "string" || !body.external_id.startsWith("rentit-")) {
      return json({ error: "Invalid external_id." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing Supabase service environment.");
      return json({ error: "Payment service is not configured." }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: order, error } = await admin
      .from("orders")
      .select("status")
      .eq("external_id", body.external_id)
      .maybeSingle();
    if (error) throw error;
    if (!order) return json({ error: "Order not found." }, 404);

    return json({ status: order.status });
  } catch (error) {
    console.error("Order status lookup failed:", error);
    return json({ error: "Could not retrieve order status." }, 500);
  }
});
