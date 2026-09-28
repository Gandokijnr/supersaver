// Run: node scripts/test-customer-accounts.mjs <directory containing node_modules/@electric-sql/pglite>
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
const require = createRequire(resolve(process.argv[2] || '.', 'package.json'))
const { PGlite } = require('@electric-sql/pglite')
const { pgcrypto } = require('@electric-sql/pglite/contrib/pgcrypto')
const db = new PGlite({ extensions: { pgcrypto } })
const sql = (query, params = []) => db.query(query, params)
const scalar = async (query, params) => Object.values((await sql(query, params)).rows[0])[0]
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth; CREATE SCHEMA extensions;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
    CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
    SET search_path = public, extensions;
  `)
  for (const file of [
    '20260823204648_create_super_saver_schema.sql',
    '20260823204711_create_order_function.sql',
    '20260824072944_create_admin_tables.sql',
    '20260824073006_admin_write_policies_and_functions.sql',
    '20260824073036_admin_login_function.sql',
    '20260824073908_fix_admin_login.sql',
    '20260824073927_fix_update_order_status.sql',
    '20260928090000_customer_accounts.sql',
  ]) await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'))

  const a = '00000000-0000-4000-8000-000000000001'
  const b = '00000000-0000-4000-8000-000000000002'
  await sql('INSERT INTO auth.users VALUES ($1), ($2)', [a, b])
  const branch = await scalar("INSERT INTO branches(name,slug,address) VALUES ('Test','test','Test') RETURNING id")
  const otherBranch = await scalar("INSERT INTO branches(name,slug,address) VALUES ('Other','other','Other') RETURNING id")
  const product = await scalar("INSERT INTO products(name,slug) VALUES ('Test item','test-item') RETURNING id")
  const inventory = await scalar('INSERT INTO branch_products(branch_id,product_id,stock_quantity,selling_price) VALUES ($1,$2,20,500) RETURNING id', [branch, product])

  async function identity(user = null, session = 'guest-a', token = '') {
    await db.exec('RESET ROLE')
    await sql("SELECT set_config('request.jwt.claim.sub',$1,false), set_config('request.headers',$2,false)", [user || '', JSON.stringify({ 'x-cart-session': session, 'x-admin-session': token })])
    await db.exec(user ? 'SET ROLE authenticated' : 'SET ROLE anon')
  }
  async function order(user, session) {
    await identity(user, session)
    const cart = await scalar('INSERT INTO carts(session_id,branch_id) VALUES ($1,$2) RETURNING id', [session, branch])
    await sql('INSERT INTO cart_items(cart_id,product_id,branch_product_id,quantity,unit_price) VALUES ($1,$2,$3,1,500)', [cart, product, inventory])
    return scalar("SELECT create_order($1,$2,'Address','Customer','08012345678')", [session, branch])
  }
  const owned = await order(a, 'account-a-cart')
  assert.equal(await scalar('SELECT customer_id FROM orders WHERE id=$1', [owned.order_id]), a)
  assert.equal(await scalar('SELECT count(*)::int FROM order_items'), 1)
  await sql('INSERT INTO customer_profiles(id,name) VALUES ($1,$2)', [a, 'Customer A'])
  await assert.rejects(() => sql('INSERT INTO customer_profiles(id,name) VALUES ($1,$2)', [b, 'Impostor']))
  await assert.rejects(() => sql("SELECT update_order_status($1,'confirmed')", [owned.order_id]))
  assert.equal((await sql("UPDATE orders SET order_status='delivered' WHERE id=$1 RETURNING id", [owned.order_id])).rows.length, 0)
  await assert.rejects(() => sql("SELECT create_order_internal('account-a-cart',$1,'Address','Name','Phone',NULL,NULL)", [branch]))
  await assert.rejects(() => sql('SELECT * FROM admin_users'))
  await assert.rejects(() => sql('SELECT * FROM admin_sessions'))

  await identity(b, 'account-a-cart') // Even knowing the old guest session must not unlock account orders.
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 0)
  assert.equal(await scalar('SELECT count(*)::int FROM order_items'), 0)
  assert.equal(await scalar('SELECT count(*)::int FROM customer_profiles'), 0)
  await identity(a, 'different-device')
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 1)
  assert.equal(await scalar('SELECT name FROM customer_profiles'), 'Customer A')
  const guest = await order(null, 'guest-cart')
  assert.equal(await scalar('SELECT customer_id FROM orders WHERE id=$1', [guest.order_id]), null)
  await identity(null, 'unrelated-device')
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 0)
  assert.equal(await scalar('SELECT count(*)::int FROM carts'), 0)
  assert.equal(await scalar('SELECT count(*)::int FROM cart_items'), 0)
  await assert.rejects(() => sql("SELECT create_order('guest-cart',$1,'Address','Name','Phone')", [branch]))

  const login = await scalar("SELECT admin_login('admin@supersaver.ng','admin123')")
  assert.ok(login.session_token)
  await identity(null, 'admin-browser', login.session_token)
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 2)
  await sql("SELECT update_order_status($1,'confirmed')", [owned.order_id])
  await identity(a, 'different-device')
  assert.equal(await scalar('SELECT to_status FROM order_status_history'), 'confirmed')
  await identity(b)
  assert.equal(await scalar('SELECT count(*)::int FROM order_status_history'), 0)
  await identity(null, 'admin-browser', 'forged-token')
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 0)
  await db.exec('RESET ROLE')
  await sql('UPDATE admin_users SET role=$1, branch_id=$2 WHERE id=$3', ['order_manager', otherBranch, login.id])
  await identity(null, 'admin-browser', login.session_token)
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 0)
  await assert.rejects(() => sql("SELECT update_order_status($1,'processing')", [owned.order_id]))
  await db.exec('RESET ROLE')
  await sql('UPDATE admin_users SET branch_id=$1 WHERE id=$2', [branch, login.id])
  await identity(null, 'admin-browser', login.session_token)
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 2)
  await db.exec('RESET ROLE')
  await sql("UPDATE admin_sessions SET expires_at=now()-interval '1 second'")
  await identity(null, 'admin-browser', login.session_token)
  assert.equal(await scalar('SELECT count(*)::int FROM orders'), 0)
  console.log('PASS: migration, account ownership, cross-device access, profile isolation, guest isolation, protected checkout, admin authentication, branch scope, status history, and token expiry.')
} finally { await db.close() }
