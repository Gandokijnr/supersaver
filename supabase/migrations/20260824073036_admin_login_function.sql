/*
# Admin Login Function + Password Column

## Overview
1. Adds a `password_hash` column to `admin_users` for simple password auth.
2. Creates `admin_login` SECURITY DEFINER function that validates credentials
   and returns the admin user row (without the password hash).
3. Sets a default password for the seeded super admin.

## Security
- Passwords are stored as bcrypt hashes via pgcrypto.
- The function never returns the password_hash column.

## Important Notes
1. Uses pgcrypto extension for crypt() and gen_salt().
2. Default admin password is "admin123".
*/

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS password_hash text;

UPDATE admin_users
SET password_hash = crypt('admin123', gen_salt('bf'))
WHERE email = 'admin@supersaver.ng' AND (password_hash IS NULL OR password_hash = '');

CREATE OR REPLACE FUNCTION admin_login(p_email text, p_password text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user admin_users%ROWTYPE;
BEGIN
  SELECT * INTO v_user FROM admin_users
  WHERE email = lower(p_email) AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  IF v_user.password_hash IS NULL OR crypt(p_password, v_user.password_hash) = false THEN
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
