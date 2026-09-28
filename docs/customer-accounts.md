# Customer accounts rollout

1. Apply `supabase/migrations/20260928090000_customer_accounts.sql` to the Supabase project together with this application release. It adds customer profiles and order ownership, scopes order/cart access, and issues expiring admin sessions. Existing orders remain guest orders; they are not assigned to an account by matching an email address.
2. In Supabase Authentication, enable the Email provider and sign-ups. Configure the production Site URL and allow the production `/profile` confirmation redirect URL (plus the development URL when needed). Configure email delivery and test email confirmation before release.
3. Admins must sign in again after the migration. Existing admin emails/passwords still work; the new database-issued session lasts 12 hours. No customer can grant themselves an admin role through account metadata.
4. Verify with two customer accounts: sign up, confirm email, save a profile, place an order while signed in, sign out, and sign in on another browser. The profile and order should follow the account. A second account must not read the first account's order, items, history, or profile even through direct database requests.
5. Verify guest checkout and tracking on the original device, plus admin order status changes. Status pages poll every 30 seconds while visible and provide a manual Refresh action.

Guest orders remain tied to the original browser shopping session. Sign in before checkout to attach a new order to an account. Previously device-only profile details are not automatically uploaded or assigned to a newly signed-in user.

Authentication follows the [Supabase JavaScript authentication API](https://supabase.com/docs/reference/javascript/auth-onauthstatechange). Customer credentials are managed by Supabase Auth; only contact and delivery details are stored in `customer_profiles`.

## Local database checks

Install `@electric-sql/pglite` in a temporary directory, then run `node scripts/test-customer-accounts.mjs <temporary-directory>`. This runs the migrations against an isolated PostgreSQL runtime with pgcrypto and checks customer ownership, cross-device access, guest isolation, protected checkout, administrator branch scope, status updates, and session expiry. It does not contact or modify the live Supabase project.
