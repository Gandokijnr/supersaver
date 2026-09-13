<script setup lang="ts">
import { formatNaira } from '~/lib/format'
import type { OrderRow, OrderItemRow } from '~/lib/types'

const route = useRoute()
const supabase = useSupabase()
const order = ref<OrderRow | null>(null)
const items = ref<OrderItemRow[]>([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  const orderNumber = route.params.orderNumber as string
  const { data: orderData, error: orderErr } = await supabase
    .from('orders')
    .select('*')
    .eq('order_number', orderNumber)
    .maybeSingle()
  if (orderErr || !orderData) {
    error.value = 'Order not found.'
    loading.value = false
    return
  }
  order.value = orderData as OrderRow
  const { data: itemData } = await supabase
    .from('order_items')
    .select('*')
    .eq('order_id', order.value.id)
  items.value = (itemData || []) as OrderItemRow[]
  loading.value = false
})

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
    <div v-else-if="error" class="card p-8 text-center text-ink-600">{{ error }}</div>
    <div v-else-if="order" class="animate-fade-in">
      <div class="card p-6 md:p-8 text-center mb-4">
        <div class="w-16 h-16 bg-brand-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-brand-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" /></svg>
        </div>
        <h1 class="text-2xl font-extrabold text-ink-800">Order Confirmed!</h1>
        <p class="text-ink-500 mt-2">Your order number is</p>
        <p class="text-3xl font-extrabold text-brand-600 mt-1">{{ order.order_number }}</p>
        <span :class="statusColors[order.order_status] || 'bg-ink-100 text-ink-700'" class="badge mt-4 capitalize">{{ order.order_status.replace(/_/g, ' ') }}</span>
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
