# RentIt

## Xendit checkout setup

The app opens Xendit's hosted invoice page. The customer chooses a payment method
there. This repository does not contain Xendit credentials: keep the Xendit
secret key on Supabase, never in Flutter or a `--dart-define`.

### 1. Configure Xendit

1. In the Xendit Dashboard, start in **Test Mode** and create a secret API key.
2. Enable the payment channels you want to offer for your account and country.
   The invoice request deliberately omits `payment_methods`, so Xendit shows the
   enabled methods on its hosted checkout page.
3. Configure an invoice/payment callback URL to:
   `https://damfkakuqaqybudsdcfo.supabase.co/functions/v1/xendit-webhook`
4. Copy the callback verification token from the Xendit Dashboard.

### 2. Deploy the Supabase backend

Install the Supabase CLI, sign in, and link this project:

```powershell
supabase login
supabase link --project-ref damfkakuqaqybudsdcfo
```

Apply the orders and rental-listings migrations and store the Xendit
credentials as Edge Function secrets:

```powershell
supabase db push
supabase secrets set XENDIT_SECRET_KEY="your-test-secret-key" XENDIT_CALLBACK_TOKEN="your-callback-token"
```

If you use the Supabase Dashboard instead of the CLI, open **SQL Editor** in
your Supabase project and run the SQL in
[`supabase/migrations/202610260001_create_orders.sql`](./supabase/migrations/202610260001_create_orders.sql).
This is Supabase/PostgreSQL SQL, not MySQL. It creates the sample product rows
and the order columns required by the invoice and callback functions. Also run
[`supabase/migrations/202610260002_create_rental_listings.sql`](./supabase/migrations/202610260002_create_rental_listings.sql)
to create the listing table used by published listings. Products and rental
listings are readable by the app; order records remain private and are queried
through the Edge Function. Listing creation is public because this app does not
currently require users to sign in.

Deploy the invoice and status functions. The webhook is called by Xendit, so
deploy it without Supabase JWT verification; it verifies Xendit's callback token
itself:

```powershell
supabase functions deploy create-invoice
supabase functions deploy get-order-status
supabase functions deploy xendit-webhook --no-verify-jwt
```

Supabase provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to Edge
Functions. The migration enables row-level security and does not grant public
access to orders; the functions use the service role only on the server.

### 3. Run the Flutter app

Use the Supabase project's **anon/public** key (not the service-role key). In
PowerShell, pass it at run time:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://damfkakuqaqybudsdcfo.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-public-key
```

For Android or iOS, replace `chrome` with the selected device. The built-in rental catalog and its authoritative prices are sample data
mirrored by the invoice function. New listings are stored in Supabase, and the
invoice function calculates their price from the stored listing record.
Listings published before the rental-listings migration were only in app memory;
publish those items again after applying the migration to get server-backed IDs.
The payment status becomes `PAID` only after the Xendit callback updates the
order in Supabase.

### Test before going live

Keep Xendit in Test Mode and use its test payment instructions to complete a
checkout. Confirm that the hosted page shows the enabled payment choices and
that the order becomes `PAID` after the callback arrives. For real charges,
finish Xendit's account verification, enable live payment channels, and deploy
with a **live** Xendit secret key and matching callback configuration.
