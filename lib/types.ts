export interface Branch {
  id: string
  name: string
  slug: string
  address: string
  phone: string | null
  opening_hours: string | null
  delivery_enabled: boolean
  delivery_fee: number
  is_active: boolean
  sort_order: number
}

export interface Category {
  id: string
  name: string
  slug: string
  parent_id: string | null
  image_url: string | null
  sort_order: number
  is_active: boolean
}

export interface Brand {
  id: string
  name: string
  slug: string
}

export interface Product {
  id: string
  name: string
  slug: string
  description: string | null
  brand_id: string | null
  category_id: string | null
  sku: string | null
  barcode: string | null
  image_url: string | null
  unit: string | null
  is_active: boolean
}

export interface BranchProduct {
  id: string
  branch_id: string
  product_id: string
  stock_quantity: number
  selling_price: number
  compare_at_price: number | null
  is_available: boolean
  is_active: boolean
}

export interface CatalogItem extends Product {
  branch_product_id: string
  stock_quantity: number
  selling_price: number
  compare_at_price: number | null
  brand_name: string | null
  brand_slug: string | null
  category_name: string | null
  category_slug: string | null
  discount_percent: number | null
}

export interface CartItemRow {
  id: string
  cart_id: string
  product_id: string
  branch_product_id: string
  quantity: number
  unit_price: number
  product: Product
  branch_product: BranchProduct
}

export interface CartRow {
  id: string
  session_id: string
  branch_id: string
  status: string
}

export interface OrderResult {
  order_id: string
  order_number: string
  subtotal: number
  delivery_fee: number
  discount: number
  total: number
}

export interface OrderRow {
  id: string
  order_number: string
  session_id: string
  branch_id: string
  subtotal: number
  delivery_fee: number
  discount: number
  total: number
  payment_status: string
  order_status: string
  delivery_address: string
  customer_name: string
  customer_phone: string
  customer_email: string | null
  delivery_instructions: string | null
  created_at: string
}

export interface OrderItemRow {
  id: string
  order_id: string
  product_id: string | null
  product_name: string
  quantity: number
  unit_price: number
  total: number
}

export interface AdminUser {
  id: string
  email: string
  name: string
  role: string
  branch_id: string | null
  is_active: boolean
}

export interface ImportJob {
  id: string
  branch_id: string
  file_name: string
  file_path: string
  file_size: number
  status: string
  total_rows: number
  processed_rows: number
  successful_rows: number
  failed_rows: number
  skipped_rows: number
  error_message: string | null
  started_at: string | null
  completed_at: string | null
  created_at: string
}

export interface AdminNotification {
  id: string
  type: string
  title: string
  message: string | null
  is_read: boolean
  related_id: string | null
  created_at: string
}

export interface AuditLog {
  id: string
  actor_email: string | null
  action: string
  entity_type: string | null
  entity_id: string | null
  old_value: any
  new_value: any
  metadata: any
  created_at: string
}
