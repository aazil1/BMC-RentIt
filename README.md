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

### 2. Configure the Supabase backend

Run the SQL files in the Supabase Dashboard's **SQL Editor**, in this order:

1. [`supabase/migrations/v1.sql`](./supabase/migrations/v1.sql) creates products and orders.
2. [`supabase/migrations/v2.sql`](./supabase/migrations/v2.sql) creates rental listings.
3. [`supabase/migrations/202610280001_create_listing_images_bucket.sql`](./supabase/migrations/202610280001_create_listing_images_bucket.sql) creates the public `listing-images` Storage bucket and its read/upload policies.
4. [`supabase/migrations/202610290001_create_listing_images.sql`](./supabase/migrations/202610290001_create_listing_images.sql) creates the listing-image metadata table and policies.
5. [`supabase/migrations/202610290002_secure_listing_ownership_and_deletion.sql`](./supabase/migrations/202610290002_secure_listing_ownership_and_deletion.sql) adds listing ownership and owner-only create, upload, and delete policies.
6. [`supabase/migrations/202610290003_order_activity_ownership.sql`](./supabase/migrations/202610290003_order_activity_ownership.sql) associates orders with their owner and lets signed-in users read their own orders.

The app uses Supabase anonymous sign-in to give each installation an owner ID.
Enable **Anonymous Sign-Ins** under **Authentication → Sign In / Providers**
before publishing listings. Listing reads remain public; creating and deleting
listings, and uploading or deleting their images, require the matching owner.
Deleting a listing through the app removes its image files from Storage and its
database rows. Listings created before owner IDs were added cannot be deleted
through the owner-only app flow. Orders created during checkout are saved with
the signed-in owner's ID and appear in Activity and Order History; older orders
without an owner ID cannot be assigned automatically.

Install the Supabase CLI, sign in, and link this project to deploy Edge
Functions and configure their secrets:

```powershell
supabase login
supabase link --project-ref damfkakuqaqybudsdcfo
supabase secrets set XENDIT_SECRET_KEY="your-test-secret-key" XENDIT_CALLBACK_TOKEN="your-callback-token"
```

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
