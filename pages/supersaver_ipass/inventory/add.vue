<script setup lang="ts">
import { validateProductImages } from '~/lib/productImages'
definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const route = useRoute()
const { admin } = useAdminAuth()
const isSuperAdmin = computed(() => ['super_admin', 'admin'].includes(admin.value?.role || ''))
const branches = ref<any[]>([])
const categories = ref<any[]>([])
const loading = ref(true)
const saving = ref(false)
const errorMsg = ref('')
const saved = ref(false)
const imageUrls = ref<string[]>([''])
const form = reactive({ branch: '', sku: '', name: '', category: '', unit: '', quantity: '', price: '' })

onMounted(async () => {
  try {
    let branchQuery = supabase.from('branches').select('id, name').order('sort_order')
    if (!isSuperAdmin.value) branchQuery = branchQuery.eq('id', admin.value?.branch_id || '')
    const [branchResult, categoryResult] = await Promise.all([
      branchQuery,
      supabase.from('categories').select('id, name').order('name'),
    ])
    if (branchResult.error) throw branchResult.error
    if (categoryResult.error) throw categoryResult.error
    branches.value = branchResult.data || []
    categories.value = categoryResult.data || []
    form.branch = branches.value.find(b => b.id === route.query.branch)?.id || branches.value[0]?.id || ''
    if (!form.branch) throw new Error('No branch is assigned. Contact an administrator before adding inventory.')
  } catch (error: any) {
    errorMsg.value = error.message
  } finally {
    loading.value = false
  }
})

async function save() {
  if (saving.value || saved.value) return
  errorMsg.value = ''
  const quantity = Number(form.quantity)
  const price = Number(form.price)
  if (!form.branch || !form.sku.trim() || !form.name.trim()) {
    errorMsg.value = 'Branch, SKU, and product name are required.'
    return
  }
  if (!isSuperAdmin.value && form.branch !== admin.value?.branch_id) {
    errorMsg.value = 'Please select your assigned branch.'
    return
  }
  if (form.quantity === '' || form.price === '' || !Number.isFinite(quantity) || !Number.isFinite(price) || quantity < 0 || price < 0 || quantity > 9999999999.99 || price > 9999999999.99) {
    errorMsg.value = 'Enter a valid, non-negative stock quantity and selling price.'
    return
  }
  saving.value = true
  try {
    const images = validateProductImages(imageUrls.value)
    // Escape LIKE wildcards so the SKU lookup is an exact, case-insensitive match.
    const sku = form.sku.trim()
    const { data: matches, error: lookupError } = await supabase.from('products')
      .select('id').ilike('sku', sku.replace(/[\\%_]/g, '\\$&')).limit(2)
    if (lookupError) throw lookupError
    if (matches && matches.length > 1) throw new Error('Multiple products use this SKU. Resolve the duplicate SKU before adding inventory.')
    let productId = matches?.[0]?.id
    if (!productId) {
      const slug = form.name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'item'
      const { data: product, error } = await supabase.from('products').insert({
        name: form.name.trim(), sku, slug: `${slug}-${crypto.randomUUID()}`,
        category_id: form.category || null, unit: form.unit.trim() || null,
        image_url: images[0] || null, images,
        is_active: true,
      }).select('id').single()
      if (error) throw error
      productId = product.id
    } else if (images.length) {
      throw new Error('This SKU already exists. Open its product page to edit images, or remove the image URLs to use its saved images.')
    }
    // Inserting preserves existing stock and prices if this branch already has the item.
    const { error } = await supabase.from('branch_products').insert({
      branch_id: form.branch, product_id: productId,
      stock_quantity: quantity, selling_price: price,
      is_available: quantity > 0, is_active: true,
    })
    if (error?.code === '23505') throw new Error('This item already exists in this branch. Open it in Inventory Management to adjust its stock.')
    if (error) throw error
    saved.value = true
  } catch (error: any) {
    errorMsg.value = error.message || 'Could not add the item. Please try again.'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <NuxtLink :to="{ path: '/supersaver_ipass/inventory', query: { branch: form.branch || undefined } }" class="text-sm text-ink-400 hover:text-brand-600 mb-4 inline-block">← Back to inventory</NuxtLink>
    <h1 class="text-2xl font-bold text-ink-800 mb-2">Add Inventory Item</h1>
    <p class="text-sm text-ink-400 mb-6">Add one item with stock and pricing for a branch.</p>
    <div v-if="loading" class="card p-6 max-w-2xl" role="status">Loading branches and categories...</div>
    <div v-else-if="saved" class="card p-6 max-w-2xl">
      <p role="status" class="text-brand-700 font-semibold mb-4">Item added successfully.</p>
      <NuxtLink :to="{ path: '/supersaver_ipass/inventory', query: { branch: form.branch } }" class="btn-primary">View Inventory</NuxtLink>
    </div>
    <form v-else class="card p-5 sm:p-6 max-w-2xl" @submit.prevent="save">
      <p v-if="errorMsg" role="alert" class="text-sm text-red-600 bg-red-50 rounded-xl p-3 mb-4">{{ errorMsg }}</p>
      <fieldset :disabled="saving" class="space-y-4">
        <div>
          <label for="item-branch" class="block text-sm font-medium text-ink-600 mb-1">Branch *</label>
          <select id="item-branch" v-model="form.branch" required :disabled="!isSuperAdmin" class="input">
            <option value="" disabled>Select a branch</option>
            <option v-for="branch in branches" :key="branch.id" :value="branch.id">{{ branch.name }}</option>
          </select>
        </div>
        <div>
          <label for="item-sku" class="block text-sm font-medium text-ink-600 mb-1">SKU / Item Code *</label>
          <input id="item-sku" v-model="form.sku" required class="input" />
          <p class="text-xs text-ink-400 mt-1">An existing SKU uses its saved product details. Existing branch stock will not be overwritten.</p>
        </div>
        <div>
          <label for="item-name" class="block text-sm font-medium text-ink-600 mb-1">Product Name *</label>
          <input id="item-name" v-model="form.name" required class="input" />
        </div>
        <div class="grid sm:grid-cols-2 gap-4">
          <div>
            <label for="item-category" class="block text-sm font-medium text-ink-600 mb-1">Category</label>
            <select id="item-category" v-model="form.category" class="input">
              <option value="">Uncategorized</option>
              <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
            </select>
          </div>
          <div>
            <label for="item-unit" class="block text-sm font-medium text-ink-600 mb-1">Unit</label>
            <input id="item-unit" v-model="form.unit" placeholder="e.g. piece, kg, pack" class="input" />
          </div>
          <div>
            <label for="item-quantity" class="block text-sm font-medium text-ink-600 mb-1">Stock Quantity *</label>
            <input id="item-quantity" v-model="form.quantity" type="number" min="0" max="9999999999.99" step="0.01" required class="input" />
          </div>
          <div>
            <label for="item-price" class="block text-sm font-medium text-ink-600 mb-1">Selling Price (₦) *</label>
            <input id="item-price" v-model="form.price" type="number" min="0" max="9999999999.99" step="0.01" required class="input" />
          </div>
        </div>
        <ProductImageFields v-model="imageUrls" />
        <button type="submit" :disabled="!form.branch" class="btn-primary w-full disabled:opacity-50">{{ saving ? 'Saving...' : 'Add Item' }}</button>
      </fieldset>
    </form>
  </div>
</template>
