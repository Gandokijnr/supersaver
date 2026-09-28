-- Apply with the matching application release. Existing admins must sign in again.
BEGIN;

CREATE TABLE public.customer_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '', phone text NOT NULL DEFAULT '', address text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY customer_profile_read ON public.customer_profiles FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY customer_profile_insert ON public.customer_profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY customer_profile_update ON public.customer_profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
GRANT SELECT, INSERT, UPDATE ON public.customer_profiles TO authenticated;

ALTER TABLE public.orders ADD COLUMN customer_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT;
CREATE INDEX orders_customer_created ON public.orders(customer_id, created_at DESC);

-- Existing admin credentials remain supported, but database access now requires
-- a server-issued, expiring token rather than a browser-supplied admin ID.
CREATE TABLE public.admin_sessions (
  token_hash text PRIMARY KEY,
  admin_id uuid NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL DEFAULT now() + interval '12 hours'
);
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_sessions FROM anon, authenticated;
REVOKE ALL ON public.admin_users FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_login(p_email text, p_password text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE v_user public.admin_users%ROWTYPE; v_token text;
BEGIN
  SELECT * INTO v_user FROM public.admin_users WHERE email = lower(p_email) AND is_active;
  IF NOT FOUND OR v_user.password_hash IS NULL OR crypt(p_password, v_user.password_hash) IS DISTINCT FROM v_user.password_hash THEN
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;
  v_token := encode(gen_random_bytes(32), 'hex');
  DELETE FROM public.admin_sessions WHERE expires_at < now();
  INSERT INTO public.admin_sessions(token_hash, admin_id) VALUES (encode(digest(v_token, 'sha256'), 'hex'), v_user.id);
  RETURN json_build_object('id', v_user.id, 'email', v_user.email, 'name', v_user.name, 'role', v_user.role,
    'branch_id', v_user.branch_id, 'is_active', v_user.is_active, 'session_token', v_token);
END;
$$;

CREATE FUNCTION public.request_cart_session() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-cart-session'
$$;

CREATE FUNCTION public.admin_can_access(p_branch uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, extensions AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_sessions s JOIN public.admin_users a ON a.id = s.admin_id
    WHERE s.token_hash = encode(digest(nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-admin-session', 'sha256'), 'hex')
      AND s.expires_at > now() AND a.is_active
      AND (a.role IN ('admin', 'super_admin') OR a.branch_id = p_branch)
  )
$$;

-- Remove every legacy permissive order/cart policy so OR-combination cannot
-- accidentally bypass ownership checks.
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public'
    AND tablename IN ('orders', 'order_items', 'order_status_history', 'carts', 'cart_items')
  LOOP EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, p.tablename); END LOOP;
END $$;

CREATE POLICY order_read ON public.orders FOR SELECT TO anon, authenticated USING (
  customer_id = auth.uid() OR (customer_id IS NULL AND session_id = public.request_cart_session()) OR public.admin_can_access(branch_id)
);
-- All order inserts/updates go through the validated functions below.
CREATE POLICY order_item_read ON public.order_items FOR SELECT TO anon, authenticated USING (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id)
);
CREATE POLICY order_history_read ON public.order_status_history FOR SELECT TO anon, authenticated USING (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id)
);
CREATE POLICY cart_access ON public.carts FOR ALL TO anon, authenticated
  USING (session_id = public.request_cart_session()) WITH CHECK (session_id = public.request_cart_session());
CREATE POLICY cart_item_access ON public.cart_items FOR ALL TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_id));

-- Ownership is assigned from the verified JWT in the same transaction as checkout.
CREATE FUNCTION public.set_order_customer() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$ BEGIN
  NEW.customer_id := auth.uid();
  RETURN NEW;
END $$;
CREATE TRIGGER set_order_customer BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_order_customer();

ALTER FUNCTION public.create_order(text, uuid, text, text, text, text, text) RENAME TO create_order_internal;
REVOKE ALL ON FUNCTION public.create_order_internal(text, uuid, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.create_order(p_session_id text, p_branch_id uuid, p_delivery_address text, p_customer_name text, p_customer_phone text,
  p_customer_email text DEFAULT NULL, p_delivery_instructions text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$ BEGIN
  IF p_session_id IS NULL OR p_session_id IS DISTINCT FROM public.request_cart_session() THEN
    RAISE EXCEPTION 'Invalid shopping session';
  END IF;
  RETURN public.create_order_internal(p_session_id, p_branch_id, p_delivery_address, p_customer_name, p_customer_phone, p_customer_email, p_delivery_instructions);
END $$;
REVOKE ALL ON FUNCTION public.create_order(text, uuid, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_order(text, uuid, text, text, text, text, text) TO anon, authenticated;

ALTER FUNCTION public.update_order_status(uuid, text, text, text) RENAME TO update_order_status_internal;
REVOKE ALL ON FUNCTION public.update_order_status_internal(uuid, text, text, text) FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.update_order_status(p_order_id uuid, p_new_status text, p_changed_by text DEFAULT NULL, p_note text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_branch uuid;
BEGIN
  SELECT branch_id INTO v_branch FROM public.orders WHERE id = p_order_id;
  IF v_branch IS NULL OR NOT public.admin_can_access(v_branch) THEN RAISE EXCEPTION 'Admin access required'; END IF;
  RETURN public.update_order_status_internal(p_order_id, p_new_status, p_changed_by, p_note);
END $$;
REVOKE ALL ON FUNCTION public.update_order_status(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_order_status(uuid, text, text, text) TO anon, authenticated;
COMMIT;
