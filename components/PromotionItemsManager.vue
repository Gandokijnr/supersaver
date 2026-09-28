<script setup lang="ts">
import { formatNaira } from '~/lib/format'

const props = defineProps<{ promotion: { id: string; name: string } }>()
const emit = defineEmits<{ close: [] }>()
const supabase = useSupabase()
const { admin } = useAdminAuth()
const allBranches = computed(() => ['admin', 'super_admin'].includes(admin.value?.role || ''))
const branches = ref<any[]>([])
const branch = ref('')
const search = ref('')
const candidates = ref<any[]>([])
const assigned = ref<any[]>([])
const selected = ref<string[]>([])
const page = ref(0)
const assignedPage = ref(0)
const more = ref(false)
const moreAssigned = ref(false)
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const message = ref('')
const assignedIds = ref<string[]>([])
let request = 0
let disposed = false
let timer: ReturnType<typeof setTimeout> | undefined

async function loadBranches() {
  loading.value = true; error.value = ''
  try {
    let query = supabase.from('branches').select('id, name').order('sort_order')
    if (!allBranches.value) query = query.eq('id', admin.value?.branch_id || '')
    const { data, error: branchError } = await query
    if (branchError) throw branchError
    branches.value = data || []
    if (!branches.value.length) throw new Error('No branch is assigned to your account.')
    branch.value = branches.value[0].id
  } catch (e: any) { error.value = e.message; loading.value = false }
}
onMounted(loadBranches)

async function load() {
  if (!branch.value || disposed) return
  const current = ++request
  loading.value = true; error.value = ''
  candidates.value = []; assigned.value = []; assignedIds.value = []
  more.value = false; moreAssigned.value = false
  try {
    let query = supabase.from('branch_products')
      .select('product_id, stock_quantity, selling_price, product:products!inner(id, name, sku, image_url)')
      .eq('branch_id', branch.value).eq('is_active', true).eq('product.is_active', true)
      .order('product_id').range(page.value * 20, page.value * 20 + 20)
    const term = search.value.trim().replace(/[^\p{L}\p{N}\s-]/gu, ' ').trim()
    if (term) query = query.or(`name.ilike.%${term}%,sku.ilike.%${term}%`, { referencedTable: 'product' })
    const [inventory, links] = await Promise.all([
      query,
      supabase.from('promotion_products').select('id, product_id, product:products(name, sku, image_url)')
        .eq('promotion_id', props.promotion.id).eq('branch_id', branch.value)
        .order('id').range(assignedPage.value * 20, assignedPage.value * 20 + 20),
    ])
    if (inventory.error) throw inventory.error
    if (links.error) throw links.error
    // Check membership for the visible search results, even when linked items span pages.
    const ids = (inventory.data || []).slice(0, 20).map(item => item.product_id)
    let memberships: string[] = []
    if (ids.length) {
      const result = await supabase.from('promotion_products').select('product_id')
        .eq('promotion_id', props.promotion.id).eq('branch_id', branch.value).in('product_id', ids)
      if (result.error) throw result.error
      memberships = (result.data || []).map(item => item.product_id)
    }
    if (current !== request || disposed) return
    candidates.value = (inventory.data || []).slice(0, 20)
    assigned.value = (links.data || []).slice(0, 20)
    more.value = (inventory.data || []).length > 20
    moreAssigned.value = (links.data || []).length > 20
    assignedIds.value = memberships
  } catch (e: any) { if (current === request) error.value = e.message || 'Could not load promotion items.' }
  finally { if (current === request) loading.value = false }
}

watch(branch, () => { page.value = 0; assignedPage.value = 0; selected.value = []; message.value = ''; void load() })
watch(search, () => {
  request++; loading.value = true; selected.value = []; page.value = 0
  clearTimeout(timer); timer = setTimeout(load, 300)
})
function changePage(delta: number, linked = false) {
  if (linked) assignedPage.value += delta
  else { page.value += delta; selected.value = [] }
  void load()
}
async function changeItems(ids: string[], remove = false) {
  if (saving.value || !ids.length) return
  saving.value = true; error.value = ''; message.value = ''
  try {
    const { error: saveError } = await supabase.rpc('manage_promotion_items', {
      p_promotion_id: props.promotion.id, p_branch_id: branch.value, p_product_ids: ids, p_remove: remove,
    })
    if (saveError) throw saveError
    selected.value = []; assignedPage.value = 0
    message.value = remove ? 'Item removed from this promotion.' : 'Selected items added to this promotion.'
    await load()
  } catch (e: any) { error.value = e.message || 'Could not update promotion items.' }
  finally { saving.value = false }
}
onUnmounted(() => { disposed = true; request++; clearTimeout(timer) })
</script>

<template>
  <section class="card p-4 sm:p-6">
    <div class="flex items-start justify-between gap-3 mb-4">
      <div><h2 class="text-xl font-bold text-ink-800">{{ promotion.name }} — Items</h2><p class="text-sm text-ink-400 mt-1">Choose the branch and add inventory items to this promotion.</p></div>
      <button type="button" :disabled="saving" class="btn-outline text-sm" @click="emit('close')">Back</button>
    </div>
    <p v-if="error" role="alert" class="text-sm text-red-600 bg-red-50 p-3 rounded-xl mb-4">{{ error }} <button type="button" class="underline" :disabled="saving" @click="branch ? load() : loadBranches()">Retry</button></p>
    <p v-if="message" role="status" class="text-sm text-brand-700 bg-brand-50 p-3 rounded-xl mb-4">{{ message }}</p>
    <fieldset :disabled="saving" class="space-y-5">
      <label class="block text-sm font-medium text-ink-600">Branch
        <select v-model="branch" :disabled="!allBranches" class="input mt-1"><option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option></select>
      </label>
      <div>
        <h3 class="font-bold text-ink-800 mb-2">Items in this promotion</h3>
        <p v-if="loading" class="text-sm text-ink-400" role="status">Loading items...</p>
        <template v-else>
          <p v-if="!assigned.length" class="text-sm text-ink-500">No items on this page for this branch.</p>
          <ul v-else class="divide-y divide-ink-100">
            <li v-for="item in assigned" :key="item.id" class="flex items-center gap-3 py-3">
              <img v-if="item.product?.image_url" :src="item.product.image_url" :alt="item.product.name" class="w-12 h-12 object-contain rounded-lg" />
              <div class="flex-1 min-w-0"><p class="font-semibold text-sm text-ink-800">{{ item.product?.name || 'Unavailable product' }}</p><p class="text-xs text-ink-400">{{ item.product?.sku || 'No SKU' }}</p></div>
              <button type="button" class="text-sm text-red-600" @click="changeItems([item.product_id], true)">Remove</button>
            </li>
          </ul>
          <div v-if="assignedPage || moreAssigned" class="flex justify-between items-center gap-3 mt-3 text-sm">
            <button type="button" :disabled="!assignedPage" class="btn-outline disabled:opacity-40" @click="changePage(-1, true)">Previous</button><span>Page {{ assignedPage + 1 }}</span><button type="button" :disabled="!moreAssigned" class="btn-outline disabled:opacity-40" @click="changePage(1, true)">Next</button>
          </div>
        </template>
      </div>
      <div>
        <h3 class="font-bold text-ink-800 mb-2">Add Inventory Items</h3>
        <label class="block text-sm text-ink-600">Search by product name or SKU<input v-model="search" type="search" class="input mt-1 mb-3" placeholder="Search items..." /></label>
        <template v-if="!loading">
          <p v-if="!candidates.length" class="text-sm text-ink-500">No matching inventory items in this branch.</p>
          <label v-for="item in candidates" :key="item.product_id" class="flex items-center gap-3 py-3 border-b border-ink-100">
            <input v-model="selected" type="checkbox" :value="item.product_id" :disabled="assignedIds.includes(item.product_id)" class="accent-brand-600" />
            <img v-if="item.product?.image_url" :src="item.product.image_url" :alt="item.product.name" class="w-12 h-12 object-contain rounded-lg" />
            <span class="flex-1 min-w-0"><span class="block text-sm font-semibold text-ink-800">{{ item.product?.name }}</span><span class="block text-xs text-ink-400">{{ item.product?.sku || 'No SKU' }} · Stock: {{ item.stock_quantity }} · {{ formatNaira(Number(item.selling_price)) }}</span></span>
            <span v-if="assignedIds.includes(item.product_id)" class="badge bg-brand-50 text-brand-700">Added</span>
          </label>
          <div v-if="page || more" class="flex justify-between items-center gap-3 mt-3 text-sm">
            <button type="button" :disabled="!page" class="btn-outline disabled:opacity-40" @click="changePage(-1)">Previous</button><span>Page {{ page + 1 }}</span><button type="button" :disabled="!more" class="btn-outline disabled:opacity-40" @click="changePage(1)">Next</button>
          </div>
        </template>
        <button type="button" :disabled="loading || !selected.length || !branch" class="btn-primary w-full mt-4 disabled:opacity-50" @click="changeItems([...selected])">{{ saving ? 'Saving...' : `Add Selected Items (${selected.length})` }}</button>
      </div>
    </fieldset>
  </section>
</template>
