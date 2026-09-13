<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const route = useRoute()
const supabase = useSupabase()

const product = ref<any>(null)
const branchProducts = ref<any[]>([])
const branches = ref<any[]>([])
const loading = ref(true)
const showAdjust = ref(false)
const adjustBP = ref<any>(null)
const adjustForm = ref({ quantity: 0, reason: '' })

onMounted(async () => {
  const id = route.params.id as string
  const { data: prod } = await supabase.from('products').select('*, category:categories(name), brand:brands(name)').eq('id', id).maybeSingle()
  if (prod) product.value = prod
  const { data: bps } = await supabase.from('branch_products').select(`
    id, stock_quantity, selling_price, compare_at_price, is_available, is_active, updated_at,
    branch:branches(id, name, slug)
  `).eq('product_id', id)
  branchProducts.value = bps || []
  const { data: brs } = await supabase.from('branches').select('id, name, slug').order('sort_order')
  branches.value = brs || []
  loading.value = false
})

function openAdjust(bp: any) {
  adjustBP.value = bp
  adjustForm.value = { quantity: Number(bp.stock_quantity), reason: '' }
  showAdjust.value = true
}

async function saveAdjust() {
  if (!adjustBP.value) return
  const oldQty = Number(adjustBP.value.stock_quantity)
  const newQty = adjustForm.value.quantity
  const { error } = await supabase.from('branch_products')
    .update({ stock_quantity: newQty, is_available: newQty > 0, updated_at: new Date().toISOString() })
    .eq('id', adjustBP.value.id)
  if (error) { alert(error.message); return }
  await supabase.from('inventory_adjustments').insert({
    branch_product_id: adjustBP.value.id,
    old_quantity: oldQty,
    new_quantity: newQty,
    reason: adjustForm.value.reason || 'Manual adjustment',
    adjusted_by: useAdminAuth().admin.value?.email || 'admin',
  })
  showAdjust.value = false
  // Reload
  const { data: bps } = await supabase.from('branch_products').select(`
    id, stock_quantity, selling_price, compare_at_price, is_available, is_active, updated_at,
    branch:branches(id, name, slug)
  `).eq('product_id', product.value.id)
  branchProducts.value = bps || []
}

async function updatePrice(bp: any, newPrice: number) {
  await supabase.from('branch_products').update({ selling_price: newPrice, updated_at: new Date().toISOString() }).eq('id', bp.id)
  const { data: bps } = await supabase.from('branch_products').select(`
    id, stock_quantity, selling_price, compare_at_price, is_available, is_active, updated_at,
    branch:branches(id, name, slug)
  `).eq('product_id', product.value.id)
  branchProducts.value = bps || []
}
</script>

<template>
  <div>
    <NuxtLink to="/supersaver_ipass/products" class="text-sm text-ink-400 hover:text-brand-600 mb-4 inline-flex items-center gap-1">← Back to products</NuxtLink>

    <div v-if="loading" class="card p-6 space-y-3"><div v-for="n in 5" :key="n" class="h-5 skeleton rounded" /></div>
    <div v-else-if="product" class="space-y-4">
      <div class="card p-5">
        <h1 class="text-xl font-bold text-ink-800">{{ product.name }}</h1>
        <p v-if="product.category" class="text-sm text-ink-400 mt-1">Category: {{ product.category?.name }}</p>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4 text-sm">
          <div><p class="text-ink-400">SKU</p><p class="font-semibold text-ink-800">{{ product.sku || '—' }}</p></div>
          <div><p class="text-ink-400">Barcode</p><p class="font-semibold text-ink-800">{{ product.barcode || '—' }}</p></div>
          <div><p class="text-ink-400">Unit</p><p class="font-semibold text-ink-800">{{ product.unit || '—' }}</p></div>
          <div><p class="text-ink-400">Active</p><span :class="product.is_active ? 'bg-brand-100 text-brand-700' : 'bg-ink-100 text-ink-500'" class="badge">{{ product.is_active ? 'Yes' : 'No' }}</span></div>
        </div>
        <p v-if="product.description" class="text-sm text-ink-600 mt-3">{{ product.description }}</p>
      </div>

      <div class="card p-5">
        <h3 class="font-bold text-ink-800 mb-4">Branch Inventory</h3>
        <div class="space-y-3">
          <div v-for="bp in branchProducts" :key="bp.id" class="flex items-center justify-between p-3 rounded-xl bg-ink-50">
            <div class="flex items-center gap-4">
              <div><p class="font-semibold text-ink-800 text-sm">{{ bp.branch?.name }}</p><p class="text-xs text-ink-400">Stock: <span :class="Number(bp.stock_quantity) <= 5 ? 'text-accent-600 font-bold' : ''">{{ bp.stock_quantity }}</span></p></div>
              <div><p class="text-sm text-ink-700">{{ formatNaira(Number(bp.selling_price)) }}</p><span :class="bp.is_available ? 'text-brand-600' : 'text-ink-400'" class="text-xs">{{ bp.is_available ? 'Available' : 'Unavailable' }}</span></div>
            </div>
            <button @click="openAdjust(bp)" class="btn-outline text-xs py-1.5 px-3">Adjust</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Adjust modal -->
    <div v-if="showAdjust" class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 p-4" @click.self="showAdjust = false">
      <div class="card p-6 max-w-sm w-full">
        <h2 class="text-lg font-bold text-ink-800 mb-4">Stock Adjustment</h2>
        <p class="text-sm text-ink-500 mb-3">{{ adjustBP?.branch?.name }} — Current: {{ adjustBP?.stock_quantity }}</p>
        <div class="space-y-3">
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">New Quantity</label><input v-model.number="adjustForm.quantity" type="number" class="input" /></div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Reason *</label><input v-model="adjustForm.reason" class="input" placeholder="e.g. Damaged products" /></div>
        </div>
        <div class="flex gap-2 mt-5">
          <button @click="showAdjust = false" class="btn-outline flex-1">Cancel</button>
          <button @click="saveAdjust" :disabled="!adjustForm.reason" class="btn-primary flex-1 disabled:opacity-50">Save</button>
        </div>
      </div>
    </div>
  </div>
</template>
