<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const customers = ref<any[]>([])
const loading = ref(true)
const search = ref('')

onMounted(load)
async function load() {
  loading.value = true
  const { data } = await supabase.from('orders').select('customer_name, customer_phone, customer_email, total, created_at').order('created_at', { ascending: false })
  if (!data) { loading.value = false; return }
  // Group by phone
  const map = new Map<string, any>()
  for (const o of data) {
    const key = o.customer_phone || o.customer_name
    if (!map.has(key)) map.set(key, { name: o.customer_name, phone: o.customer_phone, email: o.customer_email, orders: 0, totalSpend: 0, lastOrder: o.created_at })
    const c = map.get(key)
    c.orders++
    c.totalSpend += Number(o.total)
    if (o.created_at > c.lastOrder) c.lastOrder = o.created_at
  }
  customers.value = Array.from(map.values())
  loading.value = false
}

let timer: any
watch(search, () => { clearTimeout(timer); timer = setTimeout(() => {
  if (!search.value) { load(); return }
  customers.value = customers.value.filter(c => c.name?.toLowerCase().includes(search.value.toLowerCase()) || c.phone?.includes(search.value))
}, 300) })
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div><h1 class="text-2xl font-bold text-ink-800">Customers</h1><p class="text-sm text-ink-400 mt-1">Customer order history</p></div>
      <input v-model="search" type="text" placeholder="Search..." class="input max-w-xs text-sm py-2" />
    </div>
    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 5" :key="n" class="h-10 skeleton rounded-xl" /></div>
    <div v-else-if="customers.length === 0" class="card p-10 text-center"><div class="text-5xl mb-3">👥</div><h2 class="text-lg font-bold text-ink-800">No customers yet</h2><p class="text-ink-500 mt-1">Customers will appear here once orders are placed.</p></div>
    <div v-else class="card overflow-hidden">
      <div class="overflow-x-auto"><table class="w-full text-sm">
        <thead class="bg-ink-50 text-ink-500 uppercase text-xs"><tr>
          <th class="text-left px-4 py-3 font-semibold">Name</th><th class="text-left px-4 py-3 font-semibold hidden md:table-cell">Phone</th>
          <th class="text-right px-4 py-3 font-semibold">Orders</th><th class="text-right px-4 py-3 font-semibold">Total Spend</th>
          <th class="text-left px-4 py-3 font-semibold hidden lg:table-cell">Last Order</th>
        </tr></thead>
        <tbody class="divide-y divide-ink-100">
          <tr v-for="c in customers" :key="c.phone || c.name" class="hover:bg-ink-50">
            <td class="px-4 py-3 font-semibold text-ink-800">{{ c.name }}</td>
            <td class="px-4 py-3 hidden md:table-cell text-ink-600">{{ c.phone || '—' }}</td>
            <td class="px-4 py-3 text-right text-ink-700">{{ c.orders }}</td>
            <td class="px-4 py-3 text-right font-bold text-brand-600">{{ formatNaira(c.totalSpend) }}</td>
            <td class="px-4 py-3 hidden lg:table-cell text-ink-400 text-xs">{{ new Date(c.lastOrder).toLocaleDateString('en-NG', { day: 'numeric', month: 'short' }) }}</td>
          </tr>
        </tbody>
      </table></div>
    </div>
  </div>
</template>
