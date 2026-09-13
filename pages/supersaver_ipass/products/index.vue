<script setup lang="ts">
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const products = ref<any[]>([])
const categories = ref<any[]>([])
const loading = ref(true)
const search = ref('')
const showCreate = ref(false)
const saving = ref(false)
const editProduct = ref<any>(null)

const form = ref({ name: '', sku: '', barcode: '', category_id: '', description: '', unit: '' })

onMounted(async () => {
  await Promise.all([loadProducts(), loadCategories()])
})

async function loadProducts() {
  loading.value = true
  let q = supabase.from('products').select(`
    id, name, slug, sku, barcode, unit, is_active, category_id,
    category:categories(name, slug)
  `).order('created_at', { ascending: false }).limit(100)
  if (search.value) q = q.or(`name.ilike.%${search.value}%,sku.ilike.%${search.value}%`)
  const { data, error } = await q
  if (!error) products.value = data || []
  loading.value = false
}

async function loadCategories() {
  const { data } = await supabase.from('categories').select('id, name, slug').eq('is_active', true).order('name')
  categories.value = data || []
}

let timer: any
watch(search, () => { clearTimeout(timer); timer = setTimeout(loadProducts, 300) })

function openCreate() { editProduct.value = null; form.value = { name: '', sku: '', barcode: '', category_id: '', description: '', unit: '' }; showCreate.value = true }
function openEdit(p: any) {
  editProduct.value = p
  form.value = { name: p.name, sku: p.sku || '', barcode: p.barcode || '', category_id: p.category_id || '', description: p.description || '', unit: p.unit || '' }
  showCreate.value = true
}

async function save() {
  saving.value = true
  const slug = form.value.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
  const payload = { ...form.value, slug: editProduct.value ? editProduct.value.slug : slug + '-' + Date.now().toString(36) }
  try {
    if (editProduct.value) {
      const { error } = await supabase.from('products').update(payload).eq('id', editProduct.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('products').insert({ ...payload, is_active: true })
      if (error) throw error
    }
    showCreate.value = false
    await loadProducts()
  } catch (e: any) { alert(e.message) } finally { saving.value = false }
}

async function toggleActive(p: any) {
  await supabase.from('products').update({ is_active: !p.is_active }).eq('id', p.id)
  await loadProducts()
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-4 sm:mb-6 flex-wrap gap-3">
      <div><h1 class="text-xl sm:text-2xl font-bold text-ink-800">Products</h1><p class="text-sm text-ink-400 mt-1">Central product catalog</p></div>
      <button @click="openCreate" class="btn-primary text-sm">+ New Product</button>
    </div>

    <input v-model="search" type="text" placeholder="Search products..." class="input w-full sm:max-w-xs mb-4 text-sm py-2" />

    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 8" :key="n" class="h-10 skeleton rounded-xl" /></div>
    <div v-else-if="products.length === 0" class="card p-10 text-center"><div class="text-5xl mb-3">🏷</div><h2 class="text-lg font-bold text-ink-800">No products found</h2></div>
    <div v-else>
      <!-- Mobile cards -->
      <div class="md:hidden space-y-3">
        <div v-for="p in products" :key="p.id" class="card p-3 flex items-center justify-between gap-2">
          <div class="min-w-0 flex-1">
            <p class="font-semibold text-ink-800 text-sm truncate">{{ p.name }}</p>
            <p class="text-xs text-ink-400">{{ p.sku || '—' }} · {{ p.category?.name || '—' }}</p>
          </div>
          <span :class="p.is_active ? 'bg-brand-100 text-brand-700' : 'bg-ink-100 text-ink-500'" class="badge flex-shrink-0">{{ p.is_active ? 'Active' : 'Inactive' }}</span>
          <button @click="openEdit(p)" class="text-brand-600 text-xs font-semibold hover:text-brand-700 flex-shrink-0">Edit →</button>
        </div>
      </div>
      <!-- Desktop table -->
      <div class="hidden md:block card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-ink-50 text-ink-500 uppercase text-xs">
              <tr><th class="text-left px-4 py-3 font-semibold">Name</th><th class="text-left px-4 py-3 font-semibold">SKU</th><th class="text-left px-4 py-3 font-semibold hidden lg:table-cell">Category</th><th class="text-left px-4 py-3 font-semibold">Active</th><th class="px-4 py-3"></th></tr>
            </thead>
            <tbody class="divide-y divide-ink-100">
              <tr v-for="p in products" :key="p.id" class="hover:bg-ink-50">
                <td class="px-4 py-3 font-semibold text-ink-800">{{ p.name }}</td>
                <td class="px-4 py-3 text-ink-500">{{ p.sku || '—' }}</td>
                <td class="px-4 py-3 hidden lg:table-cell text-ink-500">{{ p.category?.name || '—' }}</td>
                <td class="px-4 py-3"><span :class="p.is_active ? 'bg-brand-100 text-brand-700' : 'bg-ink-100 text-ink-500'" class="badge">{{ p.is_active ? 'Active' : 'Inactive' }}</span></td>
                <td class="px-4 py-3"><button @click="openEdit(p)" class="text-brand-600 text-xs font-semibold hover:text-brand-700">Edit →</button></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Create/Edit modal -->
    <div v-if="showCreate" class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 p-4" @click.self="showCreate = false">
      <div class="card p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <h2 class="text-lg font-bold text-ink-800 mb-4">{{ editProduct ? 'Edit' : 'New' }} Product</h2>
        <div class="space-y-3">
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Name *</label><input v-model="form.name" class="input" /></div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">SKU</label><input v-model="form.sku" class="input" /></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Barcode</label><input v-model="form.barcode" class="input" /></div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Category</label>
              <select v-model="form.category_id" class="input"><option value="">—</option><option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option></select>
            </div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Unit</label><input v-model="form.unit" class="input" placeholder="e.g. 500g, 1L" /></div>
          </div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Description</label><textarea v-model="form.description" class="input" rows="3" /></div>
        </div>
        <div class="flex gap-2 mt-5">
          <button @click="showCreate = false" class="btn-outline flex-1">Cancel</button>
          <button @click="save" :disabled="saving || !form.name" class="btn-primary flex-1 disabled:opacity-50">{{ saving ? 'Saving...' : 'Save' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
