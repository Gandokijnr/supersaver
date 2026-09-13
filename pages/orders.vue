<script setup lang="ts">
import { formatNaira } from '~/lib/format'
import type { OrderRow } from '~/lib/types'

const supabase = useSupabase()
const cartStore = useCartStore()
const orders = ref<OrderRow[]>([])
const loading = ref(true)

const statusColors: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700', confirmed: 'bg-sky-100 text-sky-700',
  processing: 'bg-indigo-100 text-indigo-700', delivered: 'bg-brand-100 text-brand-700',
  cancelled: 'bg-red-100 text-red-700', failed: 'bg-red-100 text-red-700',
}

onMounted(async () => {
  const sid = cartStore.ensureSession()
  const { data, error } = await supabase.from('orders').select('*').eq('session_id', sid).order('created_at', { ascending: false })
  if (!error) orders.value = (data || []) as OrderRow[]
  loading.value = false
})
</script>

<template>
  <div class="max-w-3xl mx-auto px-4 py-6 md:py-10">
    <h1 class="text-2xl font-bold text-ink-800 mb-6">My Orders</h1>
    <div v-if="loading" class="space-y-3"><div v-for="n in 3" :key="n" class="card p-4 space-y-2"><div class="h-5 w-1/3 skeleton" /><div class="h-4 w-1/2 skeleton" /></div></div>
    <div v-else-if="orders.length === 0" class="card p-10 text-center">
      <div class="text-5xl mb-4">📦</div><h2 class="text-lg font-bold text-ink-800">No orders yet</h2>
      <p class="text-ink-500 mt-2">Your order history will appear here.</p>
      <NuxtLink to="/" class="btn-primary inline-block mt-4">Start Shopping</NuxtLink>
    </div>
    <div v-else class="space-y-3">
      <NuxtLink v-for="order in orders" :key="order.id" :to="`/order/${order.order_number}`" class="card p-4 flex items-center justify-between hover:shadow-md transition-shadow">
        <div>
          <p class="font-bold text-ink-800">{{ order.order_number }}</p>
          <p class="text-sm text-ink-500">{{ new Date(order.created_at).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' }) }}</p>
        </div>
        <div class="text-right">
          <p class="font-bold text-ink-800">{{ formatNaira(Number(order.total)) }}</p>
          <span :class="statusColors[order.order_status] || 'bg-ink-100 text-ink-700'" class="badge capitalize">{{ order.order_status.replace(/_/g, ' ') }}</span>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
