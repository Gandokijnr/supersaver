/*
# Supersaver Admin — Operations Tables

## Overview
Adds the tables needed for the admin operations console: admin users, order
status history, inventory adjustments, inventory import jobs/errors/changes,
admin notifications, and audit logs.

## New Tables

1. `admin_users` — admin/staff accounts with role + optional branch assignment
   - id, email, name, role, branch_id (nullable), is_active, created_at

2. `order_status_history` — auditable order lifecycle transitions
   - id, order_id, from_status, to_status, changed_by, note, created_at

3. `inventory_adjustments` — manual stock changes with reasons
   - id, branch_product_id, old_quantity, new_quantity, reason, adjusted_by, created_at

4. `inventory_import_jobs` — async import job tracking
   - id, branch_id, file_name, file_path, file_size, status, total_rows,
     processed_rows, successful_rows, failed_rows, skipped_rows, error_message,
     started_at, completed_at, created_at

5. `inventory_import_errors` — per-row errors from an import job
   - id, job_id, row_number, sku, error_message

6. `inventory_import_changes` — per-row changes (old vs new stock/price) for rollback
   - id, job_id, branch_product_id, old_stock, new_stock, old_price, new_price, created_at

7. `admin_notifications` — admin notification center
   - id, type, title, message, is_read, related_id, created_at

8. `audit_logs` — admin action audit trail
   - id, actor_email, action, entity_type, entity_id, old_value, new_value, metadata, created_at

## Security
- All tables have RLS enabled.
- Admin tables use `TO anon, authenticated` with open policies because the
  admin frontend uses the anon key (no Supabase Auth sign-in screen for admin
  in this phase — admin auth is handled via a simple admin_users table lookup
  through an edge function). In a production deployment these would be locked
  to `authenticated` with proper role checks, but the current storefront has no
  auth flow and the admin shares the same anon-key client.

## Important Notes
1. `order_status_history` tracks every status transition with who/when/note.
2. `inventory_import_jobs` is the async job record — the edge function reads
   the uploaded CSV from Supabase Storage and processes it in chunks, updating
   this row's progress fields as it goes.
3. `inventory_import_changes` enables rollback by storing old values.
4. `audit_logs` captures admin actions for compliance.
*/

-- ============ ADMIN_USERS ============
CREATE TABLE IF NOT EXISTS admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  name text NOT NULL,
  role text NOT NULL DEFAULT 'order_manager',
  branch_id uuid REFERENCES branches(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_admin_users" ON admin_users;
CREATE POLICY "anon_all_admin_users" ON admin_users FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_admin_users" ON admin_users FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_admin_users" ON admin_users FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_admin_users" ON admin_users FOR DELETE TO anon, authenticated USING (true);

-- ============ ORDER_STATUS_HISTORY ============
CREATE TABLE IF NOT EXISTS order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  changed_by text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_order_status_history" ON order_status_history;
CREATE POLICY "anon_all_order_status_history" ON order_status_history FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_order_status_history" ON order_status_history FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ============ INVENTORY_ADJUSTMENTS ============
CREATE TABLE IF NOT EXISTS inventory_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_product_id uuid NOT NULL REFERENCES branch_products(id) ON DELETE CASCADE,
  old_quantity numeric(12,2) NOT NULL,
  new_quantity numeric(12,2) NOT NULL,
  reason text NOT NULL,
  adjusted_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_adjustments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_inventory_adjustments" ON inventory_adjustments;
CREATE POLICY "anon_all_inventory_adjustments" ON inventory_adjustments FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_inventory_adjustments" ON inventory_adjustments FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ============ INVENTORY_IMPORT_JOBS ============
CREATE TABLE IF NOT EXISTS inventory_import_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_size bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'queued',
  total_rows int NOT NULL DEFAULT 0,
  processed_rows int NOT NULL DEFAULT 0,
  successful_rows int NOT NULL DEFAULT 0,
  failed_rows int NOT NULL DEFAULT 0,
  skipped_rows int NOT NULL DEFAULT 0,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_import_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_import_jobs" ON inventory_import_jobs;
CREATE POLICY "anon_all_import_jobs" ON inventory_import_jobs FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_import_jobs" ON inventory_import_jobs FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_import_jobs" ON inventory_import_jobs FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- ============ INVENTORY_IMPORT_ERRORS ============
CREATE TABLE IF NOT EXISTS inventory_import_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL REFERENCES inventory_import_jobs(id) ON DELETE CASCADE,
  row_number int NOT NULL,
  sku text,
  error_message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_import_errors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_import_errors" ON inventory_import_errors;
CREATE POLICY "anon_all_import_errors" ON inventory_import_errors FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_import_errors" ON inventory_import_errors FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ============ INVENTORY_IMPORT_CHANGES ============
CREATE TABLE IF NOT EXISTS inventory_import_changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL REFERENCES inventory_import_jobs(id) ON DELETE CASCADE,
  branch_product_id uuid REFERENCES branch_products(id) ON DELETE SET NULL,
  old_stock numeric(12,2),
  new_stock numeric(12,2),
  old_price numeric(12,2),
  new_price numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_import_changes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_import_changes" ON inventory_import_changes;
CREATE POLICY "anon_all_import_changes" ON inventory_import_changes FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_import_changes" ON inventory_import_changes FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ============ ADMIN_NOTIFICATIONS ============
CREATE TABLE IF NOT EXISTS admin_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  title text NOT NULL,
  message text,
  is_read boolean NOT NULL DEFAULT false,
  related_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE admin_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_admin_notifications" ON admin_notifications;
CREATE POLICY "anon_all_admin_notifications" ON admin_notifications FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_admin_notifications" ON admin_notifications FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_admin_notifications" ON admin_notifications FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- ============ AUDIT_LOGS ============
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_email text,
  action text NOT NULL,
  entity_type text,
  entity_id text,
  old_value jsonb,
  new_value jsonb,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_audit_logs" ON audit_logs;
CREATE POLICY "anon_all_audit_logs" ON audit_logs FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_audit_logs" ON audit_logs FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ============ INDEXES ============
CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_import_jobs_branch ON inventory_import_jobs(branch_id);
CREATE INDEX IF NOT EXISTS idx_import_errors_job ON inventory_import_errors(job_id);
CREATE INDEX IF NOT EXISTS idx_import_changes_job ON inventory_import_changes(job_id);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_read ON admin_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
