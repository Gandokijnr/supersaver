<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const { admin } = useAdminAuth()
const { fetchDashboardStats } = useAdminData()
const stats = ref<any>(null)
const loading = ref(true)

const branchFilter = ref<string | null>(null)
const isSuperAdmin = computed(() => admin.value?.role === 'super_admin' || admin.value?.role === 'admin')
const effectiveBranch = computed(() => isSuperAdmin.value ? branchFilter.value : admin.value?.branch_id || null)

onMounted(load)

async function load() {
  loading.value = true
  try {
    stats.value = await fetchDashboardStats(effectiveBranch.value)
  } finally { loading.value = false }
}

watch(effectiveBranch, load)

const branchStats = computed(() => {
  if (!stats.value?.allOrders || !stats.value?.branches) return []
  return stats.value.branches.map((b: any) => {
    const orders = stats.value.allOrders.filter((o: any) => o.branch_id === b.id)
    const today = new Date().toISOString().split('T')[0]
    const todayOrders = orders.filter((o: any) => o.created_at?.startsWith(today))
    const revenue = todayOrders.reduce((s: number, o: any) => s + Number(o.total), 0)
    return { ...b, orderCount: todayOrders.length, revenue }
  })
})
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-4 sm:mb-6 flex-wrap gap-3">
      <div>
        <h1 class="text-xl sm:text-2xl font-bold text-ink-800">Dashboard</h1>
        <p class="text-sm text-ink-400 mt-1">Operations overview</p>
      </div>
      <select v-if="isSuperAdmin" v-model="branchFilter" class="input w-auto text-sm py-2">
        <option :value="null">All Branches</option>
        <option v-for="b in stats?.branches || []" :key="b.id" :value="b.id">{{ b.name.replace('Supersaver ', '') }}</option>
      </select>
    </div>

    <div v-if="loading" class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div v-for="n in 8" :key="n" class="card p-5"><div class="h-4 w-1/2 skeleton mb-3" /><div class="h-8 w-3/4 skeleton" /></div>
    </div>

    <div v-else-if="stats" class="space-y-6">
      <!-- Today's overview -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        <div class="card p-4 sm:p-5">
          <p class="text-xs text-ink-400 font-medium uppercase tracking-wider">Today's Orders</p>
          <p class="text-2xl sm:text-3xl font-extrabold text-ink-800 mt-2">{{ stats.todayOrders }}</p>
        </div>
        <div class="card p-4 sm:p-5">
          <p class="text-xs text-ink-400 font-medium uppercase tracking-wider">Today's Revenue</p>
          <p class="text-2xl sm:text-3xl font-extrabold text-brand-600 mt-2">{{ formatNaira(stats.todayRevenue) }}</p>
        </div>
        <div class="card p-4 sm:p-5">
          <p class="text-xs text-ink-400 font-medium uppercase tracking-wider">Avg Order Value</p>
          <p class="text-2xl sm:text-3xl font-extrabold text-ink-800 mt-2">{{ formatNaira(stats.aov) }}</p>
        </div>
        <div class="card p-4 sm:p-5">
          <p class="text-xs text-ink-400 font-medium uppercase tracking-wider">Pending</p>
          <p class="text-2xl sm:text-3xl font-extrabold text-amber-600 mt-2">{{ stats.pending }}</p>
        </div>
      </div>

      <!-- Order status breakdown -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        <div class="card p-3 sm:p-4 flex items-center gap-3">
          <div class="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-sky-50 flex items-center justify-center text-sky-600 font-bold flex-shrink-0">{{ stats.processing }}</div>
          <div class="min-w-0"><p class="text-sm font-semibold text-ink-700 truncate">Processing</p><p class="text-xs text-ink-400">In progress</p></div>
        </div>
        <div class="card p-3 sm:p-4 flex items-center gap-3">
          <div class="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-brand-50 flex items-center justify-center text-brand-600 font-bold flex-shrink-0">{{ stats.completed }}</div>
          <div class="min-w-0"><p class="text-sm font-semibold text-ink-700 truncate">Delivered</p><p class="text-xs text-ink-400">Completed</p></div>
        </div>
        <div class="card p-3 sm:p-4 flex items-center gap-3">
          <div class="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-red-50 flex items-center justify-center text-red-600 font-bold flex-shrink-0">{{ stats.cancelled }}</div>
          <div class="min-w-0"><p class="text-sm font-semibold text-ink-700 truncate">Cancelled</p><p class="text-xs text-ink-400">Failed/cancelled</p></div>
        </div>
        <div class="card p-3 sm:p-4 flex items-center gap-3">
          <div class="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-accent-50 flex items-center justify-center text-accent-600 font-bold flex-shrink-0">{{ stats.lowStock }}</div>
          <div class="min-w-0"><p class="text-sm font-semibold text-ink-700 truncate">Low Stock</p><p class="text-xs text-ink-400">≤ 5 units</p></div>
        </div>
      </div>

      <!-- Inventory summary -->
      <div class="card p-4 sm:p-5">
        <h3 class="font-bold text-ink-800 mb-4">Inventory Summary</h3>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
          <div><p class="text-sm text-ink-400">Total Products</p><p class="text-lg sm:text-xl font-bold text-ink-800">{{ stats.productCount }}</p></div>
          <div><p class="text-sm text-ink-400">Inventory Records</p><p class="text-lg sm:text-xl font-bold text-ink-800">{{ stats.bpCount }}</p></div>
          <div><p class="text-sm text-ink-400">Low Stock Items</p><p class="text-lg sm:text-xl font-bold text-accent-600">{{ stats.lowStock }}</p></div>
          <div><p class="text-sm text-ink-400">Out of Stock</p><p class="text-lg sm:text-xl font-bold text-red-600">{{ stats.outOfStock }}</p></div>
        </div>
      </div>

      <!-- Branch performance -->
      <div v-if="isSuperAdmin && branchStats.length" class="card p-4 sm:p-5">
        <h3 class="font-bold text-ink-800 mb-4">Branch Performance (Today)</h3>
        <div class="space-y-3">
          <div v-for="b in branchStats" :key="b.id" class="flex items-center justify-between p-3 rounded-xl bg-ink-50 flex-wrap gap-2">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-2 h-2 rounded-full flex-shrink-0" :class="b.is_active ? 'bg-brand-500' : 'bg-ink-300'" />
              <div class="min-w-0"><p class="font-semibold text-ink-800 text-sm truncate">{{ b.name }}</p><p class="text-xs text-ink-400 truncate">{{ b.address }}</p></div>
            </div>
            <div class="flex items-center gap-4 sm:gap-6">
              <div class="text-right"><p class="text-xs text-ink-400">Orders</p><p class="font-bold text-ink-800">{{ b.orderCount }}</p></div>
              <div class="text-right"><p class="text-xs text-ink-400">Revenue</p><p class="font-bold text-brand-600">{{ formatNaira(b.revenue) }}</p></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
