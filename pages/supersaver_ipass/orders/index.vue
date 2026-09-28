<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const { admin } = useAdminAuth()
const { fetchOrders } = useAdminData()
const orders = ref<any[]>([])
const loading = ref(true)
const statusFilter = ref('all')
const isSuperAdmin = computed(() => admin.value?.role === 'super_admin' || admin.value?.role === 'admin')
const branchFilter = ref<string | null>(null)
const effectiveBranch = computed(() => isSuperAdmin.value ? branchFilter.value : admin.value?.branch_id || null)

const statusColors: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700', confirmed: 'bg-sky-100 text-sky-700',
  processing: 'bg-indigo-100 text-indigo-700', ready_for_delivery: 'bg-violet-100 text-violet-700',
  out_for_delivery: 'bg-blue-100 text-blue-700', delivered: 'bg-brand-100 text-brand-700',
  cancelled: 'bg-red-100 text-red-700', failed: 'bg-red-100 text-red-700',
}

const branches = ref<any[]>([])

onMounted(async () => {
  await load()
  if (isSuperAdmin.value) {
    const { data } = await useSupabase().from('branches').select('id, name').order('sort_order')
    branches.value = data || []
  }
})

async function load() {
  loading.value = true
  try {
    orders.value = await fetchOrders(effectiveBranch.value, statusFilter.value, 100)
  } finally { loading.value = false }
}

watch([statusFilter, branchFilter], load)

function timeAgo(date: string) {
  const diff = Date.now() - new Date(date).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return new Date(date).toLocaleDateString('en-NG', { day: 'numeric', month: 'short' })
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-4 sm:mb-6 flex-wrap gap-3">
      <div><h1 class="text-xl sm:text-2xl font-bold text-ink-800">Incoming Orders</h1><p class="text-sm text-ink-400 mt-1">Monitor and process new orders</p></div>
      <div class="flex gap-2 w-full sm:w-auto">
        <select v-if="isSuperAdmin" v-model="branchFilter" class="input flex-1 sm:flex-none text-sm py-2">
          <option :value="null">All Branches</option>
          <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name.replace('Supersaver ', '') }}</option>
        </select>
        <select v-model="statusFilter" class="input flex-1 sm:flex-none text-sm py-2">
          <option value="all">All Status</option>
          <option value="pending">Pending</option>
          <option value="confirmed">Confirmed</option>
          <option value="processing">Processing</option>
          <option value="ready_for_delivery">Ready</option>
          <option value="out_for_delivery">Out for Delivery</option>
          <option value="delivered">Delivered</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 5" :key="n" class="h-12 skeleton rounded-xl" /></div>
    <div v-else-if="orders.length === 0" class="card p-10 text-center">
      <div class="text-5xl mb-3">📦</div><h2 class="text-lg font-bold text-ink-800">No orders found</h2>
      <p class="text-ink-500 mt-1">New orders will appear here automatically.</p>
    </div>
    <div v-else>
      <!-- Mobile cards -->
      <div class="md:hidden space-y-3">
        <NuxtLink v-for="order in orders" :key="order.id" :to="`/supersaver_ipass/orders/${order.id}`" class="card p-4 block active:scale-[0.98] transition-transform">
          <div class="flex items-center justify-between mb-2">
            <p class="font-bold text-ink-800">{{ order.order_number }}</p>
            <span :class="statusColors[order.order_status] || 'bg-ink-100 text-ink-600'" class="badge capitalize">{{ order.order_status.replace(/_/g, ' ') }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <div><p class="text-ink-700">{{ order.customer_name }}</p><p class="text-xs text-ink-400">{{ order.customer_phone }}</p></div>
            <div class="text-right"><p class="font-bold text-ink-800">{{ formatNaira(Number(order.total)) }}</p><p class="text-xs text-ink-400">{{ timeAgo(order.created_at) }}</p></div>
          </div>
        </NuxtLink>
      </div>
      <!-- Desktop table -->
      <div class="hidden md:block card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-ink-50 text-ink-500 uppercase text-xs">
              <tr>
                <th class="text-left px-4 py-3 font-semibold">Order</th>
                <th class="text-left px-4 py-3 font-semibold">Customer</th>
                <th class="text-left px-4 py-3 font-semibold hidden lg:table-cell">Branch</th>
                <th class="text-right px-4 py-3 font-semibold">Amount</th>
                <th class="text-left px-4 py-3 font-semibold">Status</th>
                <th class="text-left px-4 py-3 font-semibold">Time</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-ink-100">
              <tr v-for="order in orders" :key="order.id" class="hover:bg-ink-50 transition-colors">
                <td class="px-4 py-3"><p class="font-bold text-ink-800">{{ order.order_number }}</p></td>
                <td class="px-4 py-3"><p class="text-ink-700">{{ order.customer_name }}</p><p class="text-xs text-ink-400">{{ order.customer_phone }}</p></td>
                <td class="px-4 py-3 hidden lg:table-cell text-ink-600">{{ order.branch_id?.slice(0, 8) }}</td>
                <td class="px-4 py-3 text-right font-bold text-ink-800">{{ formatNaira(Number(order.total)) }}</td>
                <td class="px-4 py-3"><span :class="statusColors[order.order_status] || 'bg-ink-100 text-ink-600'" class="badge capitalize">{{ order.order_status.replace(/_/g, ' ') }}</span></td>
                <td class="px-4 py-3 text-ink-400 text-xs">{{ timeAgo(order.created_at) }}</td>
                <td class="px-4 py-3"><NuxtLink :to="`/supersaver_ipass/orders/${order.id}`" class="text-brand-600 font-semibold hover:text-brand-700 text-xs">View →</NuxtLink></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
