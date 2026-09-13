/*
# Order Creation Function with Server-Side Validation

## Overview
A SECURITY DEFINER function `create_order` that validates the entire cart
server-side before creating an order. This is the single trusted path for
checkout — the frontend never sets prices or totals.

## What it does
1. Receives: session_id, branch_id, delivery_address, customer_name, phone, email, instructions.
2. Loads the active cart for (session_id, branch_id).
3. For each cart item, validates:
   - The branch_product belongs to the selected branch.
   - branch_products.is_active and is_available are true.
   - stock_quantity >= requested quantity.
   - unit_price matches the current selling_price (rejects stale client prices).
4. Computes subtotal, delivery_fee, discount, total server-side.
5. Atomically decrements stock_quantity (prevents overselling via FOR UPDATE lock).
6. Generates order_number (SS-XXXXXX format).
7. Inserts the order + order_items (snapshot of product name + price).
8. Marks the cart as 'ordered'.
9. Returns the created order row.

## Security
- SECURITY DEFINER so it can write to orders/order_items and update branch_products
  stock even though the anon role can't directly UPDATE branch_products.
- The function is callable by anon/authenticated (the storefront needs it).
- All price/stock decisions are made inside the function — client values are ignored.

## Important Notes
1. Uses SELECT ... FOR UPDATE on branch_products rows to prevent race conditions
   where two concurrent orders oversell the same stock.
2. If any item fails validation, the entire order is rejected (RAISE EXCEPTION)
   and NO stock is decremented — the transaction rolls back.
3. Order number is sequential-ish: SS- + zero-padded random 6 digits, retried on collision.
4. Delivery fee comes from the branch's delivery_fee column.
*/

CREATE OR REPLACE FUNCTION create_order(
  p_session_id text,
  p_branch_id uuid,
  p_delivery_address text,
  p_customer_name text,
  p_customer_phone text,
  p_customer_email text DEFAULT NULL,
  p_delivery_instructions text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart RECORD;
  v_cart_item RECORD;
  v_bp RECORD;
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric(12,2) := 0;
  v_delivery_fee numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_item_total numeric(12,2);
  v_attempts int := 0;
BEGIN
  -- Find the active cart for this session + branch
  SELECT * INTO v_cart
  FROM carts
  WHERE session_id = p_session_id
    AND branch_id = p_branch_id
    AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active cart found for this branch';
  END IF;

  -- Get delivery fee from branch
  SELECT delivery_fee INTO v_delivery_fee
  FROM branches WHERE id = p_branch_id AND is_active = true AND delivery_enabled = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Branch is not available for delivery';
  END IF;

  -- Validate every cart item against current branch inventory + price
  FOR v_cart_item IN
    SELECT ci.id, ci.product_id, ci.branch_product_id, ci.quantity, ci.unit_price
    FROM cart_items ci
    WHERE ci.cart_id = v_cart.id
  LOOP
    SELECT bp.stock_quantity, bp.selling_price, bp.is_available, bp.is_active
    INTO v_bp
    FROM branch_products bp
    WHERE bp.id = v_cart_item.branch_product_id
      AND bp.branch_id = p_branch_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product no longer belongs to this branch';
    END IF;

    IF v_bp.is_active = false OR v_bp.is_available = false THEN
      RAISE EXCEPTION 'A product in your cart is no longer available at this branch';
    END IF;

    IF v_bp.stock_quantity < v_cart_item.quantity THEN
      RAISE EXCEPTION 'Insufficient stock for a product in your cart (available: %)', v_bp.stock_quantity;
    END IF;

    IF v_bp.selling_price != v_cart_item.unit_price THEN
      RAISE EXCEPTION 'Price has changed for a product in your cart';
    END IF;

    v_item_total := v_bp.selling_price * v_cart_item.quantity;
    v_subtotal := v_subtotal + v_item_total;
  END LOOP;

  IF v_subtotal = 0 THEN
    RAISE EXCEPTION 'Cannot create an order with an empty cart';
  END IF;

  v_total := v_subtotal + v_delivery_fee - v_discount;

  -- Generate unique order number
  LOOP
    v_attempts := v_attempts + 1;
    v_order_number := 'SS-' || lpad(floor(random() * 1000000)::text, 6, '0');
    IF NOT EXISTS (SELECT 1 FROM orders WHERE order_number = v_order_number) THEN
      EXIT;
    END IF;
    IF v_attempts > 10 THEN
      v_order_number := 'SS-' || lpad(floor(random() * 10000000)::text, 7, '0');
      EXIT;
    END IF;
  END LOOP;

  -- Create the order
  INSERT INTO orders (
    order_number, session_id, branch_id, subtotal, delivery_fee, discount, total,
    payment_status, order_status, delivery_address, customer_name, customer_phone,
    customer_email, delivery_instructions
  ) VALUES (
    v_order_number, p_session_id, p_branch_id, v_subtotal, v_delivery_fee, v_discount, v_total,
    'pending', 'pending', p_delivery_address, p_customer_name, p_customer_phone,
    p_customer_email, p_delivery_instructions
  )
  RETURNING id INTO v_order_id;

  -- Create order items + decrement stock
  FOR v_cart_item IN
    SELECT ci.id, ci.product_id, ci.branch_product_id, ci.quantity, ci.unit_price
    FROM cart_items ci
    WHERE ci.cart_id = v_cart.id
  LOOP
    SELECT bp.selling_price INTO v_bp
    FROM branch_products bp
    WHERE bp.id = v_cart_item.branch_product_id
    FOR UPDATE;

    v_item_total := v_bp.selling_price * v_cart_item.quantity;

    INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total)
    SELECT v_order_id, p.id, p.name, v_cart_item.quantity, v_bp.selling_price, v_item_total
    FROM products p WHERE p.id = v_cart_item.product_id;

    -- Decrement stock atomically
    UPDATE branch_products
    SET stock_quantity = stock_quantity - v_cart_item.quantity,
        updated_at = now()
    WHERE id = v_cart_item.branch_product_id;
  END LOOP;

  -- Mark cart as ordered
  UPDATE carts SET status = 'ordered', updated_at = now() WHERE id = v_cart.id;

  RETURN json_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'discount', v_discount,
    'total', v_total
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_order TO anon, authenticated;
