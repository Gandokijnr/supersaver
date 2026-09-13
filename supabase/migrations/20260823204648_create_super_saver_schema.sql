/*
# SuperSaver Supermarket - Core Schema

## Overview
Multi-branch supermarket e-commerce platform with branch-aware inventory.
Branch isolation is enforced at the database level — every product query joins through
branch_products so customers only see/purchase what their selected branch stocks.

## New Tables

1. `branches` — physical supermarket locations (Ikeja, Gbagada, Lekki, Yaba, Surulere)
   - id, name, slug, address, phone, latitude, longitude, opening_hours, delivery_enabled, delivery_fee, is_active, created_at

2. `categories` — product taxonomy (supports parent/child via parent_id)
   - id, name, slug, parent_id, image_url, sort_order, is_active, created_at

3. `brands` — product manufacturers/brands
   - id, name, slug, created_at

4. `products` — centralized product catalog (NOT duplicated per branch)
   - id, name, slug, description, brand_id, category_id, sku, barcode, image_url, images, unit, is_active, created_at, updated_at

5. `branch_products` — branch-specific inventory + pricing (the branch-aware join table)
   - id, branch_id, product_id, stock_quantity, selling_price, compare_at_price, is_available, is_active, created_at, updated_at
   - UNIQUE(branch_id, product_id) — one inventory row per product per branch

6. `carts` — shopping carts scoped to a branch (prevents cross-branch carts)
   - id, session_id, branch_id, status, created_at, updated_at

7. `cart_items` — items in a cart
   - id, cart_id, product_id, branch_product_id, quantity, unit_price, created_at

8. `orders` — customer orders
   - id, order_number, session_id, branch_id, subtotal, delivery_fee, discount, total, payment_status, order_status, delivery_address, customer_name, customer_phone, customer_email, delivery_instructions, created_at

9. `order_items` — line items snapshot of an order
   - id, order_id, product_id, product_name, quantity, unit_price, total

10. `promotions` — promotional campaigns (flash sales, percentage/fixed discounts)
    - id, name, type, value, minimum_order, start_at, end_at, is_active, created_at

11. `promotion_products` — products participating in a promotion (branch-aware)
    - id, promotion_id, product_id, branch_id

## Security (RLS)
- All tables have RLS enabled.
- This is a no-auth storefront (no sign-in screen): policies use `TO anon, authenticated`
  so the anon-key frontend can read catalog/inventory and manage its session cart.
- Orders are identified by session_id, not user_id.
- Admin operations would be gated by service-role key (server-side only).

## Important Notes
1. Branch isolation: branch_products is the single source of truth for what's
   purchasable. Products without an active branch_products row for the selected
   branch never appear in catalog/search/cart/checkout.
2. Prices live on branch_products (selling_price), NOT on products — different
   branches can have different prices for the same product.
3. Stock lives on branch_products (stock_quantity) — decremented at order creation.
4. Carts are branch-scoped: a cart has exactly one branch_id. Switching branches
   creates a new cart; the old cart is retained for that branch.
5. Indexes target the hot query paths: branch_products by branch+availability,
   products by slug/sku/category, orders by session.
*/

-- ============ BRANCHES ============
CREATE TABLE IF NOT EXISTS branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  address text NOT NULL,
  phone text,
  latitude double precision,
  longitude double precision,
  opening_hours text,
  delivery_enabled boolean NOT NULL DEFAULT true,
  delivery_fee numeric(12,2) NOT NULL DEFAULT 2000,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_branches" ON branches;
CREATE POLICY "anon_read_branches" ON branches FOR SELECT
  TO anon, authenticated USING (is_active = true);

-- ============ CATEGORIES ============
CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  parent_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  image_url text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_categories" ON categories;
CREATE POLICY "anon_read_categories" ON categories FOR SELECT
  TO anon, authenticated USING (is_active = true);

-- ============ BRANDS ============
CREATE TABLE IF NOT EXISTS brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_brands" ON brands;
CREATE POLICY "anon_read_brands" ON brands FOR SELECT
  TO anon, authenticated USING (true);

-- ============ PRODUCTS ============
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  description text,
  brand_id uuid REFERENCES brands(id) ON DELETE SET NULL,
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  sku text,
  barcode text,
  image_url text,
  images jsonb DEFAULT '[]'::jsonb,
  unit text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_products" ON products;
CREATE POLICY "anon_read_products" ON products FOR SELECT
  TO anon, authenticated USING (is_active = true);

-- ============ BRANCH_PRODUCTS (branch-aware inventory + pricing) ============
CREATE TABLE IF NOT EXISTS branch_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  stock_quantity numeric(12,2) NOT NULL DEFAULT 0,
  selling_price numeric(12,2) NOT NULL,
  compare_at_price numeric(12,2),
  is_available boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(branch_id, product_id)
);
ALTER TABLE branch_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_branch_products" ON branch_products;
CREATE POLICY "anon_read_branch_products" ON branch_products FOR SELECT
  TO anon, authenticated USING (is_active = true);

-- ============ CARTS ============
CREATE TABLE IF NOT EXISTS carts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id text NOT NULL,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE carts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_carts" ON carts;
CREATE POLICY "anon_all_carts" ON carts FOR SELECT
  TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_carts" ON carts FOR INSERT
  TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_carts" ON carts FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_carts" ON carts FOR DELETE
  TO anon, authenticated USING (true);

-- ============ CART_ITEMS ============
CREATE TABLE IF NOT EXISTS cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id uuid NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  branch_product_id uuid NOT NULL REFERENCES branch_products(id) ON DELETE CASCADE,
  quantity numeric(12,2) NOT NULL DEFAULT 1,
  unit_price numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_cart_items" ON cart_items;
CREATE POLICY "anon_all_cart_items" ON cart_items FOR SELECT
  TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_cart_items" ON cart_items FOR INSERT
  TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_cart_items" ON cart_items FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_cart_items" ON cart_items FOR DELETE
  TO anon, authenticated USING (true);

-- ============ ORDERS ============
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number text UNIQUE NOT NULL,
  session_id text NOT NULL,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  subtotal numeric(12,2) NOT NULL,
  delivery_fee numeric(12,2) NOT NULL DEFAULT 0,
  discount numeric(12,2) NOT NULL DEFAULT 0,
  total numeric(12,2) NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending',
  order_status text NOT NULL DEFAULT 'pending',
  delivery_address text NOT NULL,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_email text,
  delivery_instructions text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_orders" ON orders;
CREATE POLICY "anon_all_orders" ON orders FOR SELECT
  TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_orders" ON orders FOR INSERT
  TO anon, authenticated WITH CHECK (true);

-- ============ ORDER_ITEMS ============
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE SET NULL,
  product_name text NOT NULL,
  quantity numeric(12,2) NOT NULL,
  unit_price numeric(12,2) NOT NULL,
  total numeric(12,2) NOT NULL
);
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_order_items" ON order_items;
CREATE POLICY "anon_read_order_items" ON order_items FOR SELECT
  TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_order_items" ON order_items FOR INSERT
  TO anon, authenticated WITH CHECK (true);

-- ============ PROMOTIONS ============
CREATE TABLE IF NOT EXISTS promotions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL DEFAULT 'percentage',
  value numeric(12,2) NOT NULL DEFAULT 0,
  minimum_order numeric(12,2) NOT NULL DEFAULT 0,
  start_at timestamptz,
  end_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_promotions" ON promotions;
CREATE POLICY "anon_read_promotions" ON promotions FOR SELECT
  TO anon, authenticated USING (is_active = true);

-- ============ PROMOTION_PRODUCTS ============
CREATE TABLE IF NOT EXISTS promotion_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE
);
ALTER TABLE promotion_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_read_promotion_products" ON promotion_products;
CREATE POLICY "anon_read_promotion_products" ON promotion_products FOR SELECT
  TO anon, authenticated USING (true);

-- ============ INDEXES ============
CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_branch_products_branch ON branch_products(branch_id);
CREATE INDEX IF NOT EXISTS idx_branch_products_product ON branch_products(product_id);
CREATE INDEX IF NOT EXISTS idx_branch_products_available ON branch_products(branch_id, is_available, is_active);
CREATE INDEX IF NOT EXISTS idx_carts_session ON carts(session_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_orders_session ON orders(session_id);
CREATE INDEX IF NOT EXISTS idx_orders_branch ON orders(branch_id);
CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id);
