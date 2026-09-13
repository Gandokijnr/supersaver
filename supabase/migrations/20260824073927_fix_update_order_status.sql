/*
# Fix update_order_status function — search_path issue

Same fix as admin_login: removed SET search_path = public so extension
functions and other schema objects remain accessible.
*/

CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id uuid,
  p_new_status text,
  p_changed_by text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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
