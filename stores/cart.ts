import { defineStore } from 'pinia'
import type { CartItemRow, CartRow, CatalogItem } from '~/lib/types'
import { generateSessionId } from '~/lib/format'

export const useCartStore = defineStore('cart', () => {
  const supabase = useSupabase()
  const cart = ref<CartRow | null>(null)
  const items = ref<CartItemRow[]>([])
  const loading = ref(false)
  const sessionId = ref('')

  function ensureSession(): string {
    if (!sessionId.value) {
      sessionId.value = generateSessionId()
    }
    return sessionId.value
  }

  const itemCount = computed(() =>
    items.value.reduce((sum, i) => sum + Number(i.quantity), 0)
  )

  const subtotal = computed(() =>
    items.value.reduce((sum, i) => sum + Number(i.quantity) * Number(i.unit_price), 0)
  )

  async function loadCart(branchId: string) {
    loading.value = true
    try {
      const sid = ensureSession()
      // Find or create active cart for this session+branch
      const { data: existing } = await supabase
        .from('carts')
        .select('*')
        .eq('session_id', sid)
        .eq('branch_id', branchId)
        .eq('status', 'active')
        .maybeSingle()

      let cartRow = existing as CartRow | null

      if (!cartRow) {
        const { data: created, error } = await supabase
          .from('carts')
          .insert({ session_id: sid, branch_id: branchId, status: 'active' })
          .select('*')
          .single()
        if (error) throw error
        cartRow = created as CartRow
      }

      cart.value = cartRow
      await loadItems()
    } finally {
      loading.value = false
    }
  }

  async function loadItems() {
    if (!cart.value) {
      items.value = []
      return
    }
    const { data, error } = await supabase
      .from('cart_items')
      .select(`
        *,
        product:products(*),
        branch_product:branch_products(*)
      `)
      .eq('cart_id', cart.value.id)

    if (error) throw error
    items.value = (data || []) as unknown as CartItemRow[]
  }

  async function addToCart(catalogItem: CatalogItem, quantity: number = 1) {
    if (!cart.value) throw new Error('Cart not loaded')

    // Check if item already in cart
    const existing = items.value.find(
      (i) => i.branch_product_id === catalogItem.branch_product_id
    )

    if (existing) {
      const newQty = Number(existing.quantity) + quantity
      // Validate against stock
      if (newQty > catalogItem.stock_quantity) {
        throw new Error(`Only ${catalogItem.stock_quantity} available`)
      }
      const { error } = await supabase
        .from('cart_items')
        .update({ quantity: newQty })
        .eq('id', existing.id)
      if (error) throw error
    } else {
      if (quantity > catalogItem.stock_quantity) {
        throw new Error(`Only ${catalogItem.stock_quantity} available`)
      }
      const { error } = await supabase
        .from('cart_items')
        .insert({
          cart_id: cart.value.id,
          product_id: catalogItem.id,
          branch_product_id: catalogItem.branch_product_id,
          quantity,
          unit_price: catalogItem.selling_price,
        })
      if (error) throw error
    }

    await loadItems()
  }

  async function updateQuantity(itemId: string, quantity: number, stockLimit: number) {
    if (quantity < 1) return
    if (quantity > stockLimit) {
      throw new Error(`Only ${stockLimit} available`)
    }
    const { error } = await supabase
      .from('cart_items')
      .update({ quantity })
      .eq('id', itemId)
    if (error) throw error
    await loadItems()
  }

  async function removeItem(itemId: string) {
    const { error } = await supabase
      .from('cart_items')
      .delete()
      .eq('id', itemId)
    if (error) throw error
    await loadItems()
  }

  async function clearCart() {
    if (!cart.value) return
    const { error } = await supabase
      .from('cart_items')
      .delete()
      .eq('cart_id', cart.value.id)
    if (error) throw error
    items.value = []
  }

  function reset() {
    cart.value = null
    items.value = []
  }

  return {
    cart, items, loading, sessionId,
    itemCount, subtotal,
    ensureSession, loadCart, loadItems,
    addToCart, updateQuantity, removeItem, clearCart, reset
  }
})
