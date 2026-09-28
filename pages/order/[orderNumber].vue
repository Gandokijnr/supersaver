<script setup lang="ts">
import { formatNaira } from '~/lib/format'
import type { OrderRow, OrderItemRow } from '~/lib/types'

const route = useRoute()
const supabase = useSupabase()
const order = ref<OrderRow | null>(null)
const items = ref<OrderItemRow[]>([])
const loading = ref(true)
const error = ref('')
const history = ref<{ to_status: string; created_at: string }[]>([])
const refreshError = ref('')
const { user, restore } = useCustomerAuth()
let timer: ReturnType<typeof setInterval> | undefined
let request = 0
let disposed = false

async function load() {
  if (disposed) return
  const current = ++request
  try {
  const orderNumber = route.params.orderNumber as string
  const { data: orderData, error: orderErr } = await supabase
    .from('orders')
    .select('*')
    .eq('order_number', orderNumber)
    .maybeSingle()
  if (orderErr || !orderData) {
    if (current !== request) return
    if (orderErr) throw orderErr
    order.value = null; items.value = []; history.value = []
    error.value = 'Order not found. Sign in with the account used to place this order.'
    loading.value = false
    return
  }
  const { data: itemData, error: itemError } = await supabase
    .from('order_items')
    .select('*')
    .eq('order_id', orderData.id)
  if (itemError) throw itemError
  const { data: events, error: historyError } = await supabase.from('order_status_history').select('to_status, created_at').eq('order_id', orderData.id).order('created_at')
  if (historyError) throw historyError
  if (current !== request) return
  order.value = orderData as OrderRow
  items.value = (itemData || []) as OrderItemRow[]
  history.value = events || []
  error.value = ''; refreshError.value = ''
  } catch {
    if (current === request) {
      if (order.value) refreshError.value = 'Could not refresh order status. Please try again.'
      else error.value = 'Could not load this order. Please try again.'
    }
  } finally { if (current === request) loading.value = false }
}
onMounted(async () => {
  try { await restore(); useCartStore().ensureSession(); await load() }
  catch { error.value = 'Could not restore your account. Please sign in again.'; loading.value = false }
  if (!disposed) timer = setInterval(() => { if (!document.hidden) void load() }, 30000)
})
watch(() => user.value?.id, () => { order.value = null; items.value = []; history.value = []; void load() })
onUnmounted(() => { disposed = true; request++; clearInterval(timer) })

const statusColors: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700',
  confirmed: 'bg-sky-100 text-sky-700',
  processing: 'bg-indigo-100 text-indigo-700',
  ready_for_delivery: 'bg-violet-100 text-violet-700',
  out_for_delivery: 'bg-blue-100 text-blue-700',
  delivered: 'bg-brand-100 text-brand-700',
  cancelled: 'bg-red-100 text-red-700',
  failed: 'bg-red-100 text-red-700',
}
</script>

<template>
  <div class="max-w-3xl mx-auto px-4 py-6 md:py-10">
    <div v-if="loading" class="card p-8 space-y-3"><div class="h-6 w-1/2 skeleton" /><div class="h-4 w-full skeleton" /><div class="h-4 w-2/3 skeleton" /></div>
    <div v-else-if="error" class="card p-8 text-center text-ink-600"><p>{{ error }}</p><button class="btn-outline mt-4" @click="load">Try Again</button><NuxtLink to="/account?next=/orders" class="block mt-4 text-brand-600">Sign In</NuxtLink></div>
    <div v-else-if="order" class="animate-fade-in">
      <div class="card p-6 md:p-8 text-center mb-4">
        <div class="w-16 h-16 bg-brand-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-brand-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        </div>
        <h1 class="text-2xl font-extrabold text-ink-800">Track Your Order</h1>
        <p class="text-ink-500 mt-2">Your order number is</p>
        <p class="text-3xl font-extrabold text-brand-600 mt-1">{{ order.order_number }}</p>
        <span :class="statusColors[order.order_status] || 'bg-ink-100 text-ink-700'" class="badge mt-4 capitalize">{{ order.order_status.replace(/_/g, ' ') }}</span>
      </div>

      <div class="card p-5 mb-4">
        <div class="flex justify-between items-center gap-3 mb-3"><h2 class="font-bold text-ink-800">Order Progress</h2><button class="text-sm text-brand-600 font-semibold" @click="load">Refresh</button></div>
        <p class="text-xs text-ink-400 mb-3">Updates automatically every 30 seconds.</p>
        <p v-if="refreshError" role="alert" class="text-sm text-red-600 mb-3">{{ refreshError }}</p>
        <ol class="space-y-3 text-sm">
          <li><p class="font-semibold text-ink-700">Order placed</p><time class="text-ink-400">{{ new Date(order.created_at).toLocaleString('en-NG') }}</time></li>
          <li v-for="(event, index) in history" :key="index"><p class="font-semibold text-ink-700 capitalize">{{ event.to_status.replace(/_/g, ' ') }}</p><time class="text-ink-400">{{ new Date(event.created_at).toLocaleString('en-NG') }}</time></li>
        </ol>
      </div>

      <div class="card p-5 mb-4">
        <h3 class="font-bold text-ink-800 mb-3">Items</h3>
        <div class="space-y-3">
          <div v-for="item in items" :key="item.id" class="flex justify-between text-sm">
            <div><p class="font-semibold text-ink-700">{{ item.product_name }}</p><p class="text-ink-400 text-xs">Qty: {{ item.quantity }} × {{ formatNaira(Number(item.unit_price)) }}</p></div>
            <span class="font-bold text-ink-800">{{ formatNaira(Number(item.total)) }}</span>
          </div>
        </div>
        <div class="border-t border-ink-100 mt-4 pt-3 space-y-2 text-sm">
          <div class="flex justify-between"><span class="text-ink-500">Subtotal</span><span class="font-semibold">{{ formatNaira(Number(order.subtotal)) }}</span></div>
          <div class="flex justify-between"><span class="text-ink-500">Delivery</span><span class="font-semibold">{{ formatNaira(Number(order.delivery_fee)) }}</span></div>
          <div class="flex justify-between text-base"><span class="font-bold text-ink-800">Total</span><span class="font-bold text-brand-700">{{ formatNaira(Number(order.total)) }}</span></div>
        </div>
      </div>

      <div class="card p-5 mb-4">
        <h3 class="font-bold text-ink-800 mb-3">Delivery Details</h3>
        <div class="space-y-1 text-sm">
          <p><span class="text-ink-500">Name:</span> <span class="font-semibold">{{ order.customer_name }}</span></p>
          <p><span class="text-ink-500">Phone:</span> <span class="font-semibold">{{ order.customer_phone }}</span></p>
          <p><span class="text-ink-500">Address:</span> <span class="font-semibold">{{ order.delivery_address }}</span></p>
          <p v-if="order.delivery_instructions"><span class="text-ink-500">Instructions:</span> {{ order.delivery_instructions }}</p>
        </div>
      </div>

      <div class="flex gap-3">
        <NuxtLink to="/" class="btn-outline flex-1 text-center">Continue Shopping</NuxtLink>
        <NuxtLink to="/orders" class="btn-primary flex-1 text-center">View My Orders</NuxtLink>
      </div>
    </div>
  </div>
</template>
