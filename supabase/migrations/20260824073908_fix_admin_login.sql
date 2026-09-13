/*
# Fix admin_login function — crypt() not found

## Problem
The `admin_login` function had `SET search_path = public` which prevented
PostgreSQL from finding `crypt()` from the pgcrypto extension (which lives
in the `extensions` schema, not `public`).

## Fix
Rewrote the function without `SET search_path = public` so the extension
functions remain visible. The password comparison logic is also simplified
to be clearer and avoid type confusion.
*/

CREATE OR REPLACE FUNCTION admin_login(p_email text, p_password text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user admin_users%ROWTYPE;
BEGIN
  SELECT * INTO v_user FROM admin_users
  WHERE email = lower(p_email) AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  IF v_user.password_hash IS NULL THEN
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  IF crypt(p_password, v_user.password_hash) <> v_user.password_hash THEN
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  RETURN json_build_object(
    'id', v_user.id,
    'email', v_user.email,
    'name', v_user.name,
    'role', v_user.role,
    'branch_id', v_user.branch_id,
    'is_active', v_user.is_active
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_login TO anon, authenticated;
