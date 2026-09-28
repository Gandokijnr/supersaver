<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const { admin } = useAdminAuth()
const { fetchInventory } = useAdminData()
const supabase = useSupabase()
const route = useRoute()

const isSuperAdmin = computed(() => admin.value?.role === 'super_admin' || admin.value?.role === 'admin')
const branches = ref<any[]>([])
const branchFilter = ref<string>('')
const search = ref('')
const stockFilter = ref('all')
const items = ref<any[]>([])
const loading = ref(true)
const offset = 0
const hasMore = ref(false)

const effectiveBranch = computed(() => isSuperAdmin.value ? (branchFilter.value || null) : admin.value?.branch_id || null)

onMounted(async () => {
  if (isSuperAdmin.value) {
    const { data } = await supabase.from('branches').select('id, name, slug').order('sort_order')
    branches.value = data || []
    const requestedBranch = route.query.branch
    if (branches.value.length) branchFilter.value = branches.value.find(b => b.id === requestedBranch)?.id || branches.value[0].id
  }
  await load()
})

async function load() {
  if (!effectiveBranch.value && !isSuperAdmin.value) return
  loading.value = true
  try {
    const branchId = effectiveBranch.value || branchFilter.value
    if (!branchId) return
    items.value = await fetchInventory(branchId, search.value, offset, 50)
  } finally { loading.value = false }
}

let searchTimer: any
watch(search, () => { clearTimeout(searchTimer); searchTimer = setTimeout(load, 300) })
watch(branchFilter, load)

function stockState(item: any) {
  const qty = Number(item.stock_quantity)
  if (!item.is_available) return { label: 'Unavailable', class: 'bg-ink-100 text-ink-500' }
  if (qty <= 0) return { label: 'Out of Stock', class: 'bg-red-100 text-red-700' }
  if (qty <= 5) return { label: 'Low Stock', class: 'bg-accent-100 text-accent-700' }
  return { label: 'In Stock', class: 'bg-brand-100 text-brand-700' }
}

const filtered = computed(() => {
  if (stockFilter.value === 'all') return items.value
  return items.value.filter((i: any) => {
    const s = stockState(i)
    if (stockFilter.value === 'low') return s.label === 'Low Stock'
    if (stockFilter.value === 'out') return s.label === 'Out of Stock'
    if (stockFilter.value === 'in') return s.label === 'In Stock'
    return true
  })
})
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-4 sm:mb-6 flex-wrap gap-3">
      <div><h1 class="text-xl sm:text-2xl font-bold text-ink-800">Inventory Management</h1><p class="text-sm text-ink-400 mt-1">Manage stock and pricing per branch</p></div>
      <div class="flex flex-wrap gap-2">
        <NuxtLink :to="{ path: '/supersaver_ipass/inventory/add', query: { branch: effectiveBranch || undefined } }" class="btn-primary text-sm">+ Add Item</NuxtLink>
        <NuxtLink to="/supersaver_ipass/inventory/import" class="btn-outline text-sm">↑ Import Inventory</NuxtLink>
      </div>
    </div>

    <div class="flex gap-2 sm:gap-3 mb-4 flex-wrap">
      <select v-if="isSuperAdmin" v-model="branchFilter" class="input w-full sm:w-auto text-sm py-2">
        <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name.replace('SuperSaver ', '') }}</option>
      </select>
      <input v-model="search" type="text" placeholder="Search by name or SKU..." class="input flex-1 min-w-[140px] text-sm py-2" />
      <select v-model="stockFilter" class="input w-full sm:w-auto text-sm py-2">
        <option value="all">All Stock</option>
        <option value="in">In Stock</option>
        <option value="low">Low Stock</option>
        <option value="out">Out of Stock</option>
      </select>
    </div>

    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 8" :key="n" class="h-12 skeleton rounded-xl" /></div>
    <div v-else-if="filtered.length === 0" class="card p-10 text-center">
      <div class="text-5xl mb-3">📦</div><h2 class="text-lg font-bold text-ink-800">No inventory found</h2>
      <p class="text-ink-500 mt-1">Try adjusting your filters, add a single item, or import inventory.</p>
    </div>
    <div v-else>
      <!-- Mobile cards -->
      <div class="md:hidden space-y-3">
        <NuxtLink v-for="item in filtered" :key="item.id" :to="`/supersaver_ipass/products/${item.product?.id}`" class="card p-3 block active:scale-[0.98] transition-transform">
          <div class="flex items-start justify-between gap-2 mb-2">
            <p class="font-semibold text-ink-800 text-sm flex-1">{{ item.product?.name }}</p>
            <span :class="stockState(item).class" class="badge flex-shrink-0">{{ stockState(item).label }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <div><p class="text-xs text-ink-400">{{ item.product?.sku || '—' }}</p><p class="text-xs text-ink-400">{{ item.product?.category?.name || '—' }}</p></div>
            <div class="text-right"><p class="font-bold" :class="Number(item.stock_quantity) <= 5 ? 'text-accent-600' : 'text-ink-800'">Stock: {{ item.stock_quantity }}</p><p class="font-semibold text-ink-700">{{ formatNaira(Number(item.selling_price)) }}</p></div>
          </div>
        </NuxtLink>
      </div>
      <!-- Desktop table -->
      <div class="hidden md:block card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-ink-50 text-ink-500 uppercase text-xs">
              <tr>
                <th class="text-left px-4 py-3 font-semibold">Product</th>
                <th class="text-left px-4 py-3 font-semibold">SKU</th>
                <th class="text-left px-4 py-3 font-semibold hidden lg:table-cell">Category</th>
                <th class="text-right px-4 py-3 font-semibold">Stock</th>
                <th class="text-right px-4 py-3 font-semibold">Price</th>
                <th class="text-left px-4 py-3 font-semibold">Status</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-ink-100">
              <tr v-for="item in filtered" :key="item.id" class="hover:bg-ink-50">
                <td class="px-4 py-3"><p class="font-semibold text-ink-800">{{ item.product?.name }}</p></td>
                <td class="px-4 py-3 text-ink-500">{{ item.product?.sku || '—' }}</td>
                <td class="px-4 py-3 hidden lg:table-cell text-ink-500">{{ item.product?.category?.name || '—' }}</td>
                <td class="px-4 py-3 text-right font-bold" :class="Number(item.stock_quantity) <= 5 ? 'text-accent-600' : 'text-ink-800'">{{ item.stock_quantity }}</td>
                <td class="px-4 py-3 text-right font-semibold">{{ formatNaira(Number(item.selling_price)) }}</td>
                <td class="px-4 py-3"><span :class="stockState(item).class" class="badge">{{ stockState(item).label }}</span></td>
                <td class="px-4 py-3"><NuxtLink :to="`/supersaver_ipass/products/${item.product?.id}`" class="text-brand-600 text-xs font-semibold hover:text-brand-700">Edit →</NuxtLink></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
