<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const route = useRoute()
const { admin } = useAdminAuth()
const { fetchOrder } = useAdminData()
const supabase = useSupabase()

const data = ref<any>(null)
const loading = ref(true)
const error = ref('')
const updating = ref(false)
const actionMsg = ref('')

const statusColors: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700', confirmed: 'bg-sky-100 text-sky-700',
  processing: 'bg-indigo-100 text-indigo-700', ready_for_delivery: 'bg-violet-100 text-violet-700',
  out_for_delivery: 'bg-blue-100 text-blue-700', delivered: 'bg-brand-100 text-brand-700',
  cancelled: 'bg-red-100 text-red-700', failed: 'bg-red-100 text-red-700',
}

const transitions: Record<string, { label: string; status: string }[]> = {
  pending: [{ label: 'Confirm', status: 'confirmed' }, { label: 'Cancel', status: 'cancelled' }],
  confirmed: [{ label: 'Start Processing', status: 'processing' }, { label: 'Cancel', status: 'cancelled' }],
  processing: [{ label: 'Mark Ready', status: 'ready_for_delivery' }, { label: 'Cancel', status: 'cancelled' }],
  ready_for_delivery: [{ label: 'Out for Delivery', status: 'out_for_delivery' }, { label: 'Cancel', status: 'cancelled' }],
  out_for_delivery: [{ label: 'Mark Delivered', status: 'delivered' }, { label: 'Mark Failed', status: 'failed' }],
  delivered: [], cancelled: [], failed: [],
}

onMounted(async () => {
  try {
    data.value = await fetchOrder(route.params.id as string)
    if (!data.value) error.value = 'Order not found.'
  } catch { error.value = 'Could not load order.' } finally { loading.value = false }
})

async function changeStatus(newStatus: string) {
  updating.value = true; actionMsg.value = ''
  try {
    const { error: rpcError } = await supabase.rpc('update_order_status', {
      p_order_id: route.params.id as string,
      p_new_status: newStatus,
      p_changed_by: admin.value?.email || 'admin',
    })
    if (rpcError) throw rpcError
    data.value = await fetchOrder(route.params.id as string)
    actionMsg.value = `Order status updated to ${newStatus.replace(/_/g, ' ')}`
    setTimeout(() => actionMsg.value = '', 3000)
  } catch (e: any) {
    actionMsg.value = e.message || 'Failed to update status'
  } finally { updating.value = false }
}
</script>

<template>
  <div>
    <NuxtLink to="/supersaver_ipass/orders" class="text-sm text-ink-400 hover:text-brand-600 mb-4 inline-flex items-center gap-1">← Back to orders</NuxtLink>

    <div v-if="loading" class="card p-6 space-y-3"><div v-for="n in 6" :key="n" class="h-5 skeleton rounded" /></div>
    <div v-else-if="error" class="card p-8 text-center text-ink-600">{{ error }}</div>
    <div v-else-if="data" class="grid lg:grid-cols-3 gap-4 lg:gap-6">
      <div class="lg:col-span-2 space-y-4">
        <div class="card p-4 sm:p-5">
          <div class="flex items-center justify-between mb-4 flex-wrap gap-2">
            <div><h1 class="text-lg sm:text-xl font-bold text-ink-800">{{ data.order.order_number }}</h1>
              <p class="text-sm text-ink-400 mt-1">{{ new Date(data.order.created_at).toLocaleString('en-NG', { dateStyle: 'medium', timeStyle: 'short' }) }}</p>
            </div>
            <span :class="statusColors[data.order.order_status]" class="badge capitalize text-sm px-3 py-1">{{ data.order.order_status.replace(/_/g, ' ') }}</span>
          </div>
          <div class="grid sm:grid-cols-2 gap-4 text-sm">
            <div><p class="text-ink-400 font-medium mb-1">Customer</p><p class="font-semibold text-ink-800">{{ data.order.customer_name }}</p><p class="text-ink-600">{{ data.order.customer_phone }}</p><p v-if="data.order.customer_email" class="text-ink-600 break-words">{{ data.order.customer_email }}</p></div>
            <div><p class="text-ink-400 font-medium mb-1">Delivery Address</p><p class="text-ink-700">{{ data.order.delivery_address }}</p><p v-if="data.order.delivery_instructions" class="text-ink-500 text-xs mt-1">Note: {{ data.order.delivery_instructions }}</p></div>
          </div>
        </div>

        <div class="card p-5">
          <h3 class="font-bold text-ink-800 mb-3">Items ({{ data.items.length }})</h3>
          <div class="space-y-2">
            <div v-for="item in data.items" :key="item.id" class="flex justify-between items-center p-2 rounded-lg hover:bg-ink-50">
              <div><p class="font-semibold text-ink-700 text-sm">{{ item.product_name }}</p><p class="text-xs text-ink-400">{{ item.quantity }} × {{ formatNaira(Number(item.unit_price)) }}</p></div>
              <span class="font-bold text-ink-800">{{ formatNaira(Number(item.total)) }}</span>
            </div>
          </div>
          <div class="border-t border-ink-100 mt-3 pt-3 space-y-1 text-sm">
            <div class="flex justify-between"><span class="text-ink-500">Subtotal</span><span class="font-semibold">{{ formatNaira(Number(data.order.subtotal)) }}</span></div>
            <div class="flex justify-between"><span class="text-ink-500">Delivery</span><span class="font-semibold">{{ formatNaira(Number(data.order.delivery_fee)) }}</span></div>
            <div class="flex justify-between text-base"><span class="font-bold text-ink-800">Total</span><span class="font-bold text-brand-600">{{ formatNaira(Number(data.order.total)) }}</span></div>
          </div>
        </div>

        <div v-if="data.history.length" class="card p-5">
          <h3 class="font-bold text-ink-800 mb-3">Status History</h3>
          <div class="space-y-2">
            <div v-for="h in data.history" :key="h.id" class="flex items-center gap-3 text-sm">
              <div class="w-2 h-2 rounded-full bg-brand-500" />
              <span class="text-ink-400 capitalize">{{ h.from_status?.replace(/_/g, ' ') || '—' }}</span>
              <svg class="w-4 h-4 text-ink-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
              <span class="text-ink-700 font-semibold capitalize">{{ h.to_status.replace(/_/g, ' ') }}</span>
              <span class="text-ink-400 text-xs ml-auto">{{ new Date(h.created_at).toLocaleString('en-NG', { dateStyle: 'short', timeStyle: 'short' }) }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="space-y-4">
        <div class="card p-5">
          <h3 class="font-bold text-ink-800 mb-3">Actions</h3>
          <div v-if="transitions[data.order.order_status]?.length" class="space-y-2">
            <button v-for="t in transitions[data.order.order_status]" :key="t.status" @click="changeStatus(t.status)" :disabled="updating"
              :class="t.status === 'cancelled' || t.status === 'failed' ? 'btn-outline text-red-600 border-red-200 hover:border-red-300' : 'btn-primary'" class="w-full disabled:opacity-50">
              {{ t.label }}
            </button>
          </div>
          <p v-else class="text-sm text-ink-400">No further actions available for this status.</p>
          <p v-if="actionMsg" class="text-xs mt-3 p-2 rounded-lg" :class="actionMsg.includes('Failed') || actionMsg.includes('Cannot') ? 'bg-red-50 text-red-600' : 'bg-brand-50 text-brand-700'">{{ actionMsg }}</p>
        </div>
      </div>
    </div>
  </div>
</template>
