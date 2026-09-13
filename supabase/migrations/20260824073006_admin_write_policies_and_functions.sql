/*
# Admin Write Policies + Order Status Function

## Overview
1. Adds UPDATE/INSERT/DELETE policies for admin operations on orders,
   branch_products, products, categories, branches, and promotions.
2. Creates `update_order_status` SECURITY DEFINER function that enforces
   the controlled order lifecycle, records history, and creates notifications.
3. Seeds a default super_admin user.

## Security
- The storefront uses the anon key, so admin write operations also run as anon.
- In production these would be gated behind authenticated + role checks.
- The `update_order_status` function enforces the status transition graph
  server-side regardless of who calls it.

## Important Notes
1. Order status transitions are validated against an allowed-transition map.
   Invalid transitions raise an exception (e.g. can't go from 'delivered' to 'processing').
2. Each transition is recorded in order_status_history.
3. A new-order notification is created when an order is first confirmed.
*/

-- ============ ADMIN WRITE POLICIES ============

-- Orders: allow UPDATE (admin changes status)
DROP POLICY IF EXISTS "anon_update_orders" ON orders;
CREATE POLICY "anon_update_orders" ON orders FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

-- Branch products: allow INSERT/UPDATE/DELETE (admin manages inventory)
DROP POLICY IF EXISTS "anon_insert_branch_products" ON branch_products;
CREATE POLICY "anon_insert_branch_products" ON branch_products FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_branch_products" ON branch_products;
CREATE POLICY "anon_update_branch_products" ON branch_products FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_branch_products" ON branch_products;
CREATE POLICY "anon_delete_branch_products" ON branch_products FOR DELETE
  TO anon, authenticated USING (true);

-- Products: allow INSERT/UPDATE/DELETE (admin manages catalog)
DROP POLICY IF EXISTS "anon_insert_products" ON products;
CREATE POLICY "anon_insert_products" ON products FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_products" ON products;
CREATE POLICY "anon_update_products" ON products FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_products" ON products;
CREATE POLICY "anon_delete_products" ON products FOR DELETE
  TO anon, authenticated USING (true);

-- Categories: allow INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "anon_insert_categories" ON categories;
CREATE POLICY "anon_insert_categories" ON categories FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_categories" ON categories;
CREATE POLICY "anon_update_categories" ON categories FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_categories" ON categories;
CREATE POLICY "anon_delete_categories" ON categories FOR DELETE
  TO anon, authenticated USING (true);

-- Branches: allow INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "anon_insert_branches" ON branches;
CREATE POLICY "anon_insert_branches" ON branches FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_branches" ON branches;
CREATE POLICY "anon_update_branches" ON branches FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_branches" ON branches;
CREATE POLICY "anon_delete_branches" ON branches FOR DELETE
  TO anon, authenticated USING (true);

-- Promotions: allow INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "anon_insert_promotions" ON promotions;
CREATE POLICY "anon_insert_promotions" ON promotions FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_promotions" ON promotions;
CREATE POLICY "anon_update_promotions" ON promotions FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_promotions" ON promotions;
CREATE POLICY "anon_delete_promotions" ON promotions FOR DELETE
  TO anon, authenticated USING (true);

-- Brands: allow INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "anon_insert_brands" ON brands;
CREATE POLICY "anon_insert_brands" ON brands FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_brands" ON brands;
CREATE POLICY "anon_update_brands" ON brands FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_brands" ON brands;
CREATE POLICY "anon_delete_brands" ON brands FOR DELETE
  TO anon, authenticated USING (true);

-- Promotion products: allow INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "anon_insert_promotion_products" ON promotion_products;
CREATE POLICY "anon_insert_promotion_products" ON promotion_products FOR INSERT
  TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "anon_update_promotion_products" ON promotion_products;
CREATE POLICY "anon_update_promotion_products" ON promotion_products FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_delete_promotion_products" ON promotion_products;
CREATE POLICY "anon_delete_promotion_products" ON promotion_products FOR DELETE
  TO anon, authenticated USING (true);

-- ============ UPDATE_ORDER_STATUS FUNCTION ============
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id uuid,
  p_new_status text,
  p_changed_by text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status text;
  v_allowed text[];
  v_transitions jsonb := '{
    "pending": ["confirmed", "cancelled", "failed"],
    "confirmed": ["processing", "cancelled", "failed"],
    "processing": ["ready_for_delivery", "cancelled", "failed"],
    "ready_for_delivery": ["out_for_delivery", "cancelled"],
    "out_for_delivery": ["delivered", "failed"],
    "delivered": [],
    "cancelled": [],
    "failed": []
  }'::jsonb;
BEGIN
  SELECT order_status INTO v_current_status FROM orders WHERE id = p_order_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_current_status = p_new_status THEN
    RAISE EXCEPTION 'Order is already %', p_new_status;
  END IF;

  v_allowed := ARRAY(
    SELECT jsonb_array_elements_text(v_transitions->v_current_status)
  );

  IF NOT (p_new_status = ANY(v_allowed)) THEN
    RAISE EXCEPTION 'Cannot transition from % to %', v_current_status, p_new_status;
  END IF;

  UPDATE orders SET order_status = p_new_status WHERE id = p_order_id;

  INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, note)
  VALUES (p_order_id, v_current_status, p_new_status, p_changed_by, p_note);

  IF p_new_status = 'confirmed' AND v_current_status = 'pending' THEN
    INSERT INTO admin_notifications (type, title, message, related_id)
    VALUES ('order', 'Order confirmed', 'Order has been confirmed and is ready for processing', p_order_id);
  END IF;

  RETURN json_build_object('success', true, 'order_id', p_order_id, 'from', v_current_status, 'to', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION update_order_status TO anon, authenticated;

-- ============ SEED DEFAULT ADMIN ============
INSERT INTO admin_users (email, name, role, branch_id, is_active)
SELECT 'admin@supersaver.ng', 'Super Admin', 'super_admin', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM admin_users WHERE email = 'admin@supersaver.ng');
