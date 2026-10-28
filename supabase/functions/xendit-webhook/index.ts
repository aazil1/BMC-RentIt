import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed.", { status: 405 });

  const callbackToken = Deno.env.get("XENDIT_CALLBACK_TOKEN");
  const suppliedToken = request.headers.get("x-callback-token");
  if (!callbackToken || suppliedToken !== callbackToken) {
    return new Response("Unauthorized.", { status: 401 });
  }

  try {
    const event = await request.json();
    if (
      typeof event.external_id !== "string" ||
      !["PAID", "EXPIRED"].includes(event.status)
    ) {
      return new Response("Invalid invoice callback.", { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing Supabase service environment.");
      return new Response("Payment service is not configured.", { status: 500 });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data, error } = await admin
      .from("orders")
      .update({ status: event.status })
      .eq("external_id", event.external_id)
      .select("external_id");
    if (error) throw error;
    if (!data?.length) return new Response("Order not found.", { status: 404 });

    return new Response("OK", { status: 200 });
  } catch (error) {
    console.error("Xendit callback handling failed:", error);
    return new Response("Could not process callback.", { status: 500 });
  }
});
